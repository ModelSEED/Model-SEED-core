package ModelSEED::FileDB::FileIndex;

use strict;
use warnings;

use JSON::Any;
use Archive::Zip qw( :ERROR_CODES );
use File::stat;
use Fcntl qw( :flock );
use IO::File;
use IO::String;

use Moose;
use Data::UUID;
use Digest::MD5 qw(md5_hex);

my $INDEX_FILENAME = '.index';

# External attributes (configurable)
has filename => (is => 'rw', isa => 'Str', required => 1);

=head
    uuid_index = { $uuid => { permissions => perm_obj,
                               aliases     => { $user => { $alias => 1 } },
                               md5         => $md5 } }

    $perm_obj = { public => 1 or 0,
                  users => { $user => { read  => 1 or 0,
                                        admin => 1 or 0 } } }

    user_index = { $user => { aliases => { $alias => $uuid},
                               uuids   => { $uuid  => 1} } }

    alias_index = { $user/$alias => $uuid }
=cut

sub BUILD {
    my ($self) = @_;

    unless (-f $self->filename) {
	# create archive
	my $fh = IO::File->new($self->filename, ">");
	my $archive = Archive::Zip->new();

	my $indices = {
	    uuid_index  => {},
	    user_index  => {},
	    alias_index => {}
	};

        $archive->addString(_encode($indices), $INDEX_FILENAME);

	unless ($archive->writeToFileHandle($fh, 1) == AZ_OK) {
	    die "Could not create database: " . $self->filename;
	}

	$fh->close;
    }
}

sub _do_while_locked {
    my ($self, $sub, $args) = @_;

    # first get a locked filehandle
    my $fh = IO::File->new($self->filename, "+<");
    flock $fh, LOCK_EX;

    # now load the zip archive from the file
    my $archive = Archive::Zip->new();
    unless ($archive->readFromFileHandle($fh) == AZ_OK) {
	die "";
    }

    # now read the indices
    my $indices = _decode($archive->contents($INDEX_FILENAME));

    # run the code
    my ($data, $save) = $sub->($args, $indices, $archive);

    if ($save) {
	# save the indices
	$archive->contents($INDEX_FILENAME, _encode($indices));

	# funky work-around, can't write directly to the locked filehandle
	# ($fh), so write to a string, then write that into the file
	my $fs = IO::String->new;

	unless ($archive->writeToFileHandle($fs) == AZ_OK) {
	    die "";
	}

	$fh->truncate(0);
	$fh->seek(0, 0);
	$fs->seek(0, 0);
	while (<$fs>) {
	    print $fh $_;
	}
    }

    # unlock and close
    $fh->close();

    return $data;
}

sub has_object {
    my ($self, $args) = @_;

    return $self->_do_while_locked(\&_has_object, $args);
}

sub _has_object {
    my ($args, $indices, $archive) = @_;

    my $uuid = _get_uuid($args, $indices);

    unless(defined($uuid)) {
	return 0;
    }

    # check permissions
    my $user = $args->{user};
    if (defined($user)) {
	if ($indices->{user_index}->{$user}->{uuids}->{$uuid}) {
	    return 1;
	}
    } else {
	if ($indices->{uuid_index}->{$uuid}->{permissions}->{public}) {
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
    my ($args, $indices, $archive) = @_;

    unless (_has_object($args, $indices, $archive)) {
	return;
    }

    my $uuid = _get_uuid($args, $indices);

    return _decode($archive->contents($uuid))
}

sub save_object {
    my ($self, $args) = @_;

    return $self->_do_while_locked(\&_save_object, $args);
}

sub _save_object {
    my ($args, $indices, $archive) = @_;

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

    if (defined($uuid) && defined($indices->{uuid_index}->{$uuid})) {
	# object exists, check if this is the same object
	my $md5 = md5_hex(_encode($object));

	if ($md5 eq $indices->{uuid_index}->{$uuid}->{md5}) {
	    # same, do nothing
	    return $uuid;
	} else {
	    # different, create new uuid, update own aliases, copy perms
	    my $perms   = $indices->{uuid_index}->{$uuid}->{permissions};
	    my $aliases = $indices->{uuid_index}->{$uuid}->{aliases};

	    $uuid = Data::UUID->new()->create_str();
	    $object->{uuid} = $uuid;

	    # copy aliases
	    my $new_aliases = {
		$user => {}
	    };

	    foreach my $alias (keys %{$aliases->{$user}}) {
		$new_aliases->{$user}->{$alias} = 1;
		$indices->{alias_index}->{$user.'/'.$alias} = $uuid;
		$indices->{user_index}->{$user}->{aliases}->{$alias} = $uuid;
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

	    $indices->{uuid_index}->{$uuid} = {
		permissions => $new_perms,
		aliases => $new_aliases,
		md5 => md5_hex(_encode($object))
	    };

	    $indices->{user_index}->{$user}->{uuids}->{$uuid} = 1;
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

	$indices->{uuid_index}->{$uuid} = {
	    permissions => $perm,
	    aliases => {},
	    md5 => md5_hex(_encode($object))
	};

	$indices->{user_index}->{$user}->{uuids}->{$uuid} = 1;
    }

    $archive->addString(_encode($object), $uuid);

    return ($uuid, 1);
}

sub get_user_uuids {
    my ($self, $user) = @_;

    return $self->_do_while_locked(\&_get_user_uuids, $user);
}

sub _get_user_uuids {
    my ($user, $indices, $archive) = @_;

    my @uuids = keys %{$indices->{user_index}->{$user}->{uuids}};

    return \@uuids;
}

sub get_user_aliases {
    my ($self, $user) = @_;

    return $self->_do_while_locked(\&_get_user_aliases, $user);
}

sub _get_user_aliases {
    my ($user, $indices, $archive) = @_;

    my @aliases = keys %{$indices->{user_index}->{$user}->{aliases}};

    return \@aliases;
}

sub add_alias {
    my ($self, $args) = @_;

    return $self->_do_while_locked(\&_add_alias, $args);
}

sub _add_alias {
    my ($args, $indices, $archive) = @_;

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
    if (!$indices->{user_index}->{$user}->{uuids}->{$uuid}) {
	return 0;
    }

    $indices->{alias_index}->{$user.'/'.$alias} = $uuid;
    $indices->{uuid_index}->{$uuid}->{aliases}->{$user}->{$alias} = 1;
    $indices->{user_index}->{$user}->{aliases}->{$alias} = $uuid;

    return (1, 1);
}

sub remove_alias {
    my ($self, $args) = @_;

    return $self->_do_while_locked(\&_remove_alias, $args);
}

sub _remove_alias {
    my ($args, $indices, $archive) = @_;

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
    if (!$indices->{user_index}->{$user}->{uuids}->{$uuid}) {
	return 0;
    }

    delete $indices->{alias_index}->{$user.'/'.$alias};
    delete $indices->{uuid_index}->{$uuid}->{aliases}->{$user}->{$alias};
    delete $indices->{user_index}->{$user}->{aliases}->{$alias};

    return (1, 1);
}

sub get_permissions {
    my ($self, $args) = @_;

    return $self->_do_while_locked(\&_get_permissions, $args);
}

sub _get_permissions {
    my ($args, $indices, $archive) = @_;

    my $uuid = _get_uuid($args, $indices);
    my $user = $args->{user};

    unless (defined($uuid) && defined($user)) {
	return;
    }

    # user must have admin permission
    my $perms = $indices->{uuid_index}->{$uuid}->{permissions};
    if ($perms->{users}->{$user}->{admin}) {
	return $perms;
    }
}

sub set_permissions {
    my ($self, $args) = @_;

    return $self->_do_while_locked(\&_set_permissions, $args);
}

sub _set_permissions {
    my ($args, $indices, $archive) = @_;

    my $uuid = _get_uuid($args, $indices);
    my $user = $args->{user};
    my $perms = $args->{permissions};

    unless (defined($uuid) && defined($user) && defined($perms)) {
	return 0;
    }

    # user must have admin permission
    my $old_perms = $indices->{uuid_index}->{$uuid}->{permissions};
    unless ($old_perms->{users}->{$user}->{admin}) {
	return 0;
    }

    # should make sure new perms have an admin user


    $indices->{uuid_index}->{$uuid}->{permissions} = $perms;

    # need to determine which users have lost and which
    # have gained permissions, then change indices accordingly
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
	$indices->{user_index}->{$new_user}->{uuids}->{$uuid} = 1;
    }

    foreach my $old_user (keys %$old_users) {
	_delete_object({ user => $old_user, uuid => $uuid }, $indices, $archive);
    }

    return (1, 1);
}

sub delete_object {
    my ($self, $args) = @_;

    return $self->_do_while_locked(\&_delete_object, $args);
}

sub _delete_object {
    my ($args, $indices, $archive) = @_;

    my $uuid = _get_uuid($args, $indices);
    my $user = $args->{user};

    unless (defined($uuid) && defined($user)) {
	return 0;
    }

    unless($indices->{user_index}->{$user}->{uuids}->{$uuid}) {
	return 0;
    }

    # remove the aliases
    foreach my $alias (keys %{$indices->{uuid_index}->{$uuid}->{aliases}->{$user}}) {
	_remove_alias({ user => $user, uuid => $uuid, alias => $alias }, $indices, $archive);
    }

    # remove user permissions on object
    delete $indices->{uuid_index}->{$uuid}->{permissions}->{users}->{$user};
    delete $indices->{user_index}->{$user}->{uuids}->{$uuid};

    # remove if no users in permissions
    if (scalar keys %{$indices->{uuid_index}->{$uuid}->{permissions}->{users}} == 0) {
	# remove from archive
	delete $indices->{uuid_index}->{$uuid};
    }

    return (1, 1);
}

sub _sleep_test {
    my ($self, $time) = @_;

    $self->_do_while_locked(sub {
	my ($time, $indices, $archive) = @_;

	print "Sleeping for $time seconds...\n";
	my $sleep = sleep $time;
	print "Slept for $sleep seconds\n";
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
    my ($args, $indices) = @_;

    my $uuid = $args->{uuid};
    my $user_alias = $args->{user_alias};

    if (defined($uuid)) {
        return $uuid;
    } elsif (defined($user_alias)) {
        # find uuid for alias
        my $id = $indices->{alias_index}->{$user_alias};
        if (defined($id)) {
            return $id;
        }
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;
