package ModelSEED::FileDB::FileIndex;

use strict;
use warnings;

use JSON::Any;
use File::stat;

use Moose;
use Data::UUID;
use Digest::MD5 qw(md5_hex);

has filename => (is => 'rw', isa => 'Str', required => 1);

my $filename;
my $loaded = 0;
my $mod_time = 0;


=head

$uuid_index = { $uuid => { permissions => perm_obj,
                           aliases     => { $user => { $alias => 1 } },
                           md5         => $md5 } }

$perm_obj = { public => 1 or 0,
              users => { $user => { read  => 1 or 0,
                                    admin => 1 or 0 } } }

$user_index = { $user => { aliases => { $alias => $uuid},
                           uuids   => { $uuid  => 1} } }

$alias_index => { $user/$alias => $uuid }

=cut

my $uuid_index  = {};
my $user_index  = {};
my $alias_index = {};

sub BUILD {
    my ($self) = @_;

    $filename = $self->filename;

    # check if the file exists, if not then create it
    if (!-e $filename) {
	$loaded = 1;
	_save_index();
    }
}

sub has_object {
    my ($self, $args) = @_;

    _update_index();

    my $uuid = _get_uuid($args);

    unless(defined($uuid)) {
	return 0;
    }

    # check permissions
    my $user = $args->{user};
    if (defined($user)) {
	if ($user_index->{$user}->{uuids}->{$uuid}) {
	    return 1;
	}
    } else {
	if ($uuid_index->{$uuid}->{permissions}->{public}) {
	    return 1;
	}
    }

    return 0;
}

# get_object with uuid or user/name
sub get_object {
    my ($self, $args) = @_;

    unless ($self->has_object($args)) {
	return;
    }

    my $uuid = _get_uuid($args);

    open FILE, "<$uuid";
    my $data = _decode(<FILE>);
    close FILE;

    return $data;
}

sub save_object {
    my ($self, $args) = @_;

    _update_index();

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

    if (defined($uuid) && defined($uuid_index->{$uuid})) {
	# object exists, check if this is the same object
	my $md5 = md5_hex(_encode($object));

	if ($md5 eq $uuid_index->{$uuid}->{md5}) {
	    # same, do nothing
	    _save_index();
	    return $uuid;
	} else {
	    # different, create new uuid, update own aliases, copy perms
	    my $perms   = $uuid_index->{$uuid}->{permissions};
	    my $aliases = $uuid_index->{$uuid}->{aliases};

	    $uuid = Data::UUID->new()->create_str();
	    $object->{uuid} = $uuid;

	    # copy aliases
	    my $new_aliases = {
		$user => {}
	    };

	    foreach my $alias (keys %{$aliases->{$user}}) {
		$new_aliases->{$user}->{$alias} = 1;
		$alias_index->{$user.'/'.$alias} = $uuid;
		$user_index->{$user}->{aliases}->{$alias} = $uuid;
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

	    $uuid_index->{$uuid} = {
		permissions => $new_perms,
		aliases => $new_aliases,
		md5 => md5_hex(_encode($object))
	    };

	    $user_index->{$user}->{uuids}->{$uuid} = 1;
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

	$uuid_index->{$uuid} = {
	    permissions => $perm,
	    aliases => {},
	    md5 => md5_hex(_encode($object))
	};

	$user_index->{$user}->{uuids}->{$uuid} = 1;
    }

    open FILE, ">$uuid";
    print FILE _encode($object);
    close FILE;

    _save_index();

    return $uuid;
}

sub get_user_uuids {
    my ($self, $user) = @_;

    _update_index();

    my @uuids = keys %{$user_index->{$user}->{uuids}};

    return \@uuids;
}

sub get_user_aliases {
    my ($self, $user) = @_;

    _update_index();

    my @aliases = keys %{$user_index->{$user}->{aliases}};

    return \@aliases;
}

sub add_alias {
    my ($self, $args) = @_;

    _update_index();

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
    if (!$user_index->{$user}->{uuids}->{$uuid}) {
	return;
    }

    $alias_index->{$user.'/'.$alias} = $uuid;
    $uuid_index->{$uuid}->{aliases}->{$user}->{$alias} = 1;
    $user_index->{$user}->{aliases}->{$alias} = $uuid;

    _save_index();
}

sub remove_alias {
    my ($self, $args) = @_;

    _update_index();

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
    if (!$user_index->{$user}->{uuids}->{$uuid}) {
	return;
    }

    delete $alias_index->{$user.'/'.$alias};
    delete $uuid_index->{$uuid}->{aliases}->{$user}->{$alias};
    delete $user_index->{$user}->{aliases}->{$alias};

    _save_index();
}

sub get_permissions {
    my ($self, $args) = @_;

    _update_index();

    my $uuid = _get_uuid($args);
    my $user = $args->{user};

    unless (defined($uuid) && defined($user)) {
	return;
    }

    # user must have admin permission
    my $perms = $uuid_index->{$uuid}->{permissions};
    if ($perms->{users}->{$user}->{admin}) {
	return $perms;
    }
}

sub set_permissions {
    my ($self, $args) = @_;

    _update_index();

    my $uuid = _get_uuid($args);
    my $user = $args->{user};
    my $perms = $args->{permissions};

    unless (defined($uuid) && defined($user) && defined($perms)) {
	return;
    }

    # user must have admin permission
    my $old_perms = $uuid_index->{$uuid}->{permissions};
    unless ($old_perms->{users}->{$user}->{admin}) {
	return;
    }

    # should make sure new perms have an admin user


    $uuid_index->{$uuid}->{permissions} = $perms;

    # need to determine which users have lost and which
    # have gained permissions, then change indexes accordingly
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
	$user_index->{$new_user}->{uuids}->{$uuid} = 1;
    }

    foreach my $old_user (keys %$old_users) {
	$self->delete_object({ user => $old_user, uuid => $uuid });
    }

    _save_index();
}

# not working
sub delete_object {
    my ($self, $args) = @_;

    _update_index();

    my $uuid = _get_uuid($args);
    my $user = $args->{user};

    unless (defined($uuid) && defined($user)) {
	return;
    }

    unless($user_index->{$user}->{uuids}->{$uuid}) {
	return;
    }

    # remove the aliases
    foreach my $alias (keys %{$uuid_index->{$uuid}->{aliases}->{$user}}) {
	$self->remove_alias({ user => $user, uuid => $uuid, alias => $alias });
    }

    # remove user permissions on object
    delete $uuid_index->{$uuid}->{permissions}->{users}->{$user};
    delete $user_index->{$user}->{uuids}->{$uuid};

    # remove if no users in permissions
    if (scalar keys %{$uuid_index->{$uuid}->{permissions}->{users}} == 0) {
	unlink $uuid or die "Could not delete file $uuid: $!";
	delete $uuid_index->{$uuid};
    }

    _save_index();
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
    my ($args) = @_;

    my $uuid = $args->{uuid};
    my $user_alias = $args->{user_alias};

    if (defined($uuid)) {
	return $uuid;
    } elsif (defined($user_alias)) {
	# find uuid for alias
	my $id = $alias_index->{$user_alias};
	if (defined($id)) {
	    return $id;
	}
    }
}

sub _load_index {
    open FILE, "<$filename"
	or die "Couldn't open file '$filename': $!";
    my $indexes = _decode(<FILE>);
    close FILE;

    $uuid_index  = $indexes->{uuid_index};
    $user_index  = $indexes->{user_index};
    $alias_index = $indexes->{alias_index};

    $loaded = 1;
}

sub _save_index {
    my $indexes = {
	uuid_index  => $uuid_index,
	user_index  => $user_index,
	alias_index => $alias_index
    };

    open FILE, ">$filename"
	or die "Couldn't open file '$filename': $!";
    print FILE _encode($indexes);
    close FILE;

    # update the mod time
    $mod_time = _get_mod_time();
}

sub _update_index {
    my ($self) = @_;

    if (!$loaded || $mod_time != _get_mod_time()) {
	_load_index();
    }
}

sub _get_mod_time {
    return stat($filename)->mtime;
}

no Moose;
__PACKAGE__->meta->make_immutable;
