package ModelSEED::FileDB::FileIndex;

use strict;
use warnings;

use Moose;

use JSON::Any;
use Data::UUID;
use Digest::MD5 qw(md5_hex);

use Fcntl qw( :flock );
use File::stat; # for testing mod time
use IO::Compress::Gzip qw(gzip);
use IO::Uncompress::Gunzip qw(gunzip);

=head

TODO
  * Put index file back in memory (stored in moose object)
      - test if changed via mod time and size
      - should speed up data access (as long as index hasn't changed)

=cut

my $INDEX_EXT = 'ind';
my $DATA_EXT = 'dat';

# External attributes (configurable)
has filename => (is => 'rw', isa => 'Str', required => 1);

=head
    Index Structure

    index = {
        uuid_index => { $uuid => { permissions => $perm_obj,
                                   aliases     => { $user => { $alias => 1 } },
                                   md5         => $md5,
                                   start       => $start_pos,
                                   end         => $end_pos } }

            perm_obj = { public => 1 or 0,
                         users => { $user => { read  => 1 or 0,
                                               admin => 1 or 0 } } }

        user_index => { $user => { aliases => { $alias => $uuid},
                                   uuids   => { $uuid  => 1} } }

        alias_index => { $user/$alias => $uuid }

	end_pos => int

	num_del => int

	ordered_uuids => [uuid, uuid, uuid, ...]
    }

=cut

sub BUILD {
    my ($self) = @_;

    my $file = $self->filename;

    my $ind = -f "$file.$INDEX_EXT";
    my $dat = -f "$file.$DATA_EXT";

    if ($ind && $dat) {
	# both exist
    } elsif ($ind && !$dat) {
	die "Error with index and data files: $file";
    } elsif (!$ind && $dat) {
	die "Error with index and data files: $file";
    } else {
	my $index = _initialize_index();

	open INDEX, ">$file.$INDEX_EXT" or die "";
	flock INDEX, LOCK_EX or die "";
	print INDEX _encode($index);
	close INDEX;

	open DATA, ">$file.$DATA_EXT" or die;
	flock DATA, LOCK_EX or die "";
	close DATA;
    }
}

sub _initialize_index {
    return {
	end_pos       => 0,
	num_del       => 0,
	ordered_uuids => [],
	uuid_index    => {},
	user_index    => {},
	alias_index   => {}
    };
}

sub _do_while_locked {
    my ($self, $sub, $args) = @_;

    # get locked filehandles for index and data files
    my $file = $self->filename;

    open INDEX, "+<$file.$INDEX_EXT" or die "";
    flock INDEX, LOCK_EX or die "";

    open DATA, "+<$file.$DATA_EXT" or die "";
    flock DATA, LOCK_EX or die "";

    # now read the index
    my $index = _decode(<INDEX>);

    # run the code
    my ($data, $save) = $sub->($args, $index, *DATA);

    if ($save) {
	# save the index
	truncate INDEX, 0 or die "";
	seek INDEX, 0, 0 or die "";
	print INDEX _encode($index);
    }

    # close (and unlock) filehandles
    close INDEX;
    close DATA;

    return $data;
}

# removes deleted objects from the data file
# this locks the database while rebuilding
sub rebuild_data {
    my ($self) = @_;

    return $self->_do_while_locked(\&_rebuild_data, $self->filename);
}

sub _rebuild_data {
    my ($filename, $index, $data_fh) = @_;

    my $end = -1;
    my $uuids = [];
    my $first = 1;
    foreach my $uuid (@{$index->{ordered_uuids}}) {
	if (defined($index->{uuid_index}->{$uuid})) {
	    my $uuid_hash = $index->{uuid_index}->{$uuid};
	    my $length = $uuid_hash->{end} - $uuid_hash->{start} + 1;

	    unless ($first) {
		my $data;
		seek $data_fh, $uuid_hash->{start}, 0 or die "";
		read $data_fh, $data, $length;

		$uuid_hash->{start} = $end + 1;
		$uuid_hash->{end} = $end + $length;

		seek $data_fh, $uuid_hash->{start}, 0 or die "";
		print $data_fh $data;
	    }

	    $end += $length;
	    push(@$uuids, $uuid);
	} else {
	    $first = 0;
	}
    }

    $end++;
    $index->{num_del} = 0;
    $index->{end_pos} = $end;
    $index->{ordered_uuids} = $uuids;

    truncate $data_fh, $end or die "";

    return (1, 1);
}

sub _get_ordered_uuids {
    my ($self) = @_;

    return $self->_do_while_locked(sub {
	my ($args, $index, $data_fh) = @_;

	return $index->{ordered_uuids};
    });
}

sub has_object {
    my ($self, $args) = @_;

    return $self->_do_while_locked(\&_has_object, $args);
}

sub _has_object {
    my ($args, $index, $data_fh) = @_;

    my $uuid = _get_uuid($args, $index);

    unless(defined($uuid)) {
	return 0;
    }

    # check permissions
    my $user = $args->{user};
    if (defined($user)) {
	if ($index->{user_index}->{$user}->{uuids}->{$uuid}) {
	    return 1;
	}
    } else {
	if ($index->{uuid_index}->{$uuid}->{permissions}->{public}) {
	    return 1;
	}
    }

    return 0;
}

# get_object with uuid or user/name
sub get_object {
    my ($self, $args) = @_;

    return $self->_do_while_locked(\&_get_object, $args);
}

sub _get_object {
    my ($args, $index, $data_fh) = @_;

    unless (_has_object($args, $index, $data_fh)) {
	return;
    }

    my $uuid = _get_uuid($args, $index);

    my $start = $index->{uuid_index}->{$uuid}->{start};
    my $end   = $index->{uuid_index}->{$uuid}->{end};

    my $gzip_data;
    seek $data_fh, $start, 0 or die "";
    read $data_fh, $gzip_data, ($end - $start + 1);

    my $data;
    gunzip \$gzip_data => \$data;

    return _decode($data)
}

sub save_object {
    my ($self, $args) = @_;

    return $self->_do_while_locked(\&_save_object, $args);
}

sub _save_object {
    my ($args, $index, $data_fh) = @_;

    # args must be: user, object
    foreach my $arg (qw(user object)) {
	if (!defined($args->{$arg})) {
	    # TODO: error
	    return;
	}
    }

    my $user = $args->{user};
    my $object = $args->{object};
    my $uuid = $object->{uuid};

    if (defined($uuid) && defined($index->{uuid_index}->{$uuid})) {
	# object exists, check if this is the same object
	my $md5 = md5_hex(_encode($object));

	if ($md5 eq $index->{uuid_index}->{$uuid}->{md5}) {
	    # same, do nothing
	    return $uuid;
	} else {
	    # different, create new uuid, update own aliases, copy perms
	    my $perms   = $index->{uuid_index}->{$uuid}->{permissions};
	    my $aliases = $index->{uuid_index}->{$uuid}->{aliases};

	    $uuid = Data::UUID->new()->create_str();
	    $object->{uuid} = $uuid;

	    # copy aliases
	    my $new_aliases = {
		$user => {}
	    };

	    foreach my $alias (keys %{$aliases->{$user}}) {
		$new_aliases->{$user}->{$alias} = 1;
		$index->{alias_index}->{$user.'/'.$alias} = $uuid;
		$index->{user_index}->{$user}->{aliases}->{$alias} = $uuid;
	    }

	    # delete old aliases from uuid index
	    delete $aliases->{$user};

	    my $new_perms = {
		public => $perms->{public},
		users => {}
	    };

	    foreach my $u (keys %{$perms->{users}}) {
		$new_perms->{users}->{$u} = {
		    read => $perms->{users}->{$u}->{read},
		    admin => 0
		};
	    }

	    # add admin perm for $user
	    $new_perms->{users}->{$user} = {
		read  => 1,
		admin => 1
	    };

	    $index->{uuid_index}->{$uuid} = {
		permissions => $new_perms,
		aliases => $new_aliases,
		md5 => md5_hex(_encode($object))
	    };

	    $index->{user_index}->{$user}->{uuids}->{$uuid} = 1;
	}
    } else {
	if (!defined($uuid)) {
	    $uuid = Data::UUID->new()->create_str();
	    $object->{uuid} = $uuid;
	}

	# new object, grant all permissions
	my $perm = {
	    public => 0,
	    users => {
		$user => {
		    read  => 1,
		    admin => 1
		}
	    }
	};

	$index->{uuid_index}->{$uuid} = {
	    permissions => $perm,
	    aliases => {},
	    md5 => md5_hex(_encode($object))
	};

	$index->{user_index}->{$user}->{uuids}->{$uuid} = 1;
    }

    my $data = _encode($object);
    my $gzip_data;

    gzip \$data => \$gzip_data or die "";

    my $start = $index->{end_pos};

    seek $data_fh, $start, 0 or die "";
    print $data_fh $gzip_data;

    $index->{uuid_index}->{$uuid}->{start} = $start;
    $index->{uuid_index}->{$uuid}->{end}   = $start + length($gzip_data) - 1;

    push(@{$index->{ordered_uuids}}, $uuid);
    $index->{end_pos} = $start + length($gzip_data);

    return ($uuid, 1);
}

sub get_user_uuids {
    my ($self, $user) = @_;

    return $self->_do_while_locked(\&_get_user_uuids, $user);
}

sub _get_user_uuids {
    my ($user, $index, $data_fh) = @_;

    my @uuids = keys %{$index->{user_index}->{$user}->{uuids}};

    return \@uuids;
}

sub get_user_aliases {
    my ($self, $user) = @_;

    return $self->_do_while_locked(\&_get_user_aliases, $user);
}

sub _get_user_aliases {
    my ($user, $index, $data_fh) = @_;

    my @aliases = keys %{$index->{user_index}->{$user}->{aliases}};

    return \@aliases;
}

sub set_alias {
    my ($self, $args) = @_;

    return $self->_do_while_locked(\&_set_alias, $args);
}

sub _set_alias {
    my ($args, $index, $data_fh) = @_;

    # args must be: user, uuid, alias
    foreach my $arg (qw(user uuid alias)) {
	if (!defined($args->{$arg})) {
	    # TODO: error
	    return 0;
	}
    }

    my $user  = $args->{user};
    my $uuid  = $args->{uuid};
    my $alias = $args->{alias};

    # user must be able to read object
    if (!$index->{user_index}->{$user}->{uuids}->{$uuid}) {
	return 0;
    }

    $index->{alias_index}->{$user.'/'.$alias} = $uuid;
    $index->{uuid_index}->{$uuid}->{aliases}->{$user}->{$alias} = 1;
    $index->{user_index}->{$user}->{aliases}->{$alias} = $uuid;

    return (1, 1);
}

sub remove_alias {
    my ($self, $args) = @_;

    return $self->_do_while_locked(\&_remove_alias, $args);
}

sub _remove_alias {
    my ($args, $index, $data_fh) = @_;

    # args must be: user, uuid, alias
    foreach my $arg (qw(user uuid alias)) {
	if (!defined($args->{$arg})) {
	    # TODO: error
	    return;
	}
    }

    my $user  = $args->{user};
    my $uuid  = $args->{uuid};
    my $alias = $args->{alias};

    # user must be able to read object
    if (!$index->{user_index}->{$user}->{uuids}->{$uuid}) {
	return 0;
    }

    delete $index->{alias_index}->{$user.'/'.$alias};
    delete $index->{uuid_index}->{$uuid}->{aliases}->{$user}->{$alias};
    delete $index->{user_index}->{$user}->{aliases}->{$alias};

    return (1, 1);
}

sub get_permissions {
    my ($self, $args) = @_;

    return $self->_do_while_locked(\&_get_permissions, $args);
}

sub _get_permissions {
    my ($args, $index, $data_fh) = @_;

    my $uuid = _get_uuid($args, $index);
    my $user = $args->{user};

    unless (defined($uuid) && defined($user)) {
	return;
    }

    # user must have admin permission
    my $perms = $index->{uuid_index}->{$uuid}->{permissions};
    if ($perms->{users}->{$user}->{admin}) {
	return $perms;
    }
}

sub set_permissions {
    my ($self, $args) = @_;

    return $self->_do_while_locked(\&_set_permissions, $args);
}

sub _set_permissions {
    my ($args, $index, $data_fh) = @_;

    my $uuid = _get_uuid($args, $index);
    my $user = $args->{user};
    my $perms = $args->{permissions};

    unless (defined($uuid) && defined($user) && defined($perms)) {
	return 0;
    }

    # user must have admin permission
    my $old_perms = $index->{uuid_index}->{$uuid}->{permissions};
    unless ($old_perms->{users}->{$user}->{admin}) {
	return 0;
    }

    # should make sure new perms have an admin user

    $index->{uuid_index}->{$uuid}->{permissions} = $perms;

    # need to determine which users have lost and which
    # have gained permissions, then change index accordingly
    my $old_users = {};
    my $new_users = {};

    foreach my $old_user (keys %{$old_perms->{users}}) {
	if ($old_perms->{users}->{$old_user}->{read}) {
	    $old_users->{$old_user} = 1;
	}
    }

    foreach my $new_user (keys %{$perms->{users}}) {
	if ($perms->{users}->{$new_user}->{read}) {
	    if (defined($old_users->{$new_user})) {
		delete $old_users->{$new_user};
	    } else {
		$new_users->{$new_user} = 1;
	    }
	}
    }

    # add the uuid for the new users
    foreach my $new_user (keys %$new_users) {
	$index->{user_index}->{$new_user}->{uuids}->{$uuid} = 1;
    }

    foreach my $old_user (keys %$old_users) {
	_delete_object({ user => $old_user, uuid => $uuid }, $index, $data_fh);
    }

    return (1, 1);
}

sub delete_object {
    my ($self, $args) = @_;

    return $self->_do_while_locked(\&_delete_object, $args);
}

sub _delete_object {
    my ($args, $index, $data_fh) = @_;

    my $uuid = _get_uuid($args, $index);
    my $user = $args->{user};

    unless (defined($uuid) && defined($user)) {
	return 0;
    }

    unless($index->{user_index}->{$user}->{uuids}->{$uuid}) {
	return 0;
    }

    # remove the aliases
    foreach my $alias (keys %{$index->{uuid_index}->{$uuid}->{aliases}->{$user}}) {
	_remove_alias({ user => $user, uuid => $uuid, alias => $alias }, $index, $data_fh);
    }

    # remove user permissions on object
    delete $index->{uuid_index}->{$uuid}->{permissions}->{users}->{$user};
    delete $index->{user_index}->{$user}->{uuids}->{$uuid};

    # remove if no users in permissions
    if (scalar keys %{$index->{uuid_index}->{$uuid}->{permissions}->{users}} == 0) {
	# should we rebuild the database every once in a while?
	delete $index->{uuid_index}->{$uuid};
	$index->{num_del}++;
    }

    return (1, 1);
}

sub _sleep_test {
    my ($self, $time) = @_;

    $self->_do_while_locked(sub {
	my ($time, $index, $data_fh) = @_;
	my $sleep = sleep $time;
    }, $time);
}

sub _encode {
    my ($data) = @_;

    return JSON::Any->encode($data);
}

sub _decode {
    my ($data) = @_;

    return JSON::Any->decode($data);
}

# returns the uuid, or undef if not found
sub _get_uuid {
    my ($args, $index) = @_;

    my $uuid = $args->{uuid};
    my $user_alias = $args->{user_alias};

    if (defined($uuid)) {
        return $uuid;
    } elsif (defined($user_alias)) {
        # find uuid for alias
        my $id = $index->{alias_index}->{$user_alias};
        if (defined($id)) {
            return $id;
        }
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;
