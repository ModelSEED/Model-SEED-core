package ModelSEED::FileDB::FileIndex;

use strict;
use warnings;

use JSON::Any;
use Archive::Zip;
use File::stat;

use Moose;
use Data::UUID;
use Digest::MD5 qw(md5_hex);

my $INDEX_FILENAME = '.index';

# External attributes (configurable)
has filename => (is => 'rw', isa => 'Str', required => 1);


# Interal attributes (not configurable)
has archive => (
    is        => 'rw',
    isa       => 'Archive::Zip::Archive',
    init_arg  => undef,
    builder   => '_initArchive',
    lazy      => 1,
);
has loaded   => (is => 'rw', isa => 'Bool', init_arg => undef);
has mod_time => (is => 'rw', isa => 'Int',  init_arg => undef);
has uuid_index => (
    is       => 'rw',
    isa      => 'HashRef',
    init_arg => undef,
    builder  => '_hashref'
);
has user_index => (
    is       => 'rw',
    isa      => 'HashRef',
    init_arg => undef,
    builder  => '_hashref'
);
has alias_index => (
    is       => 'rw',
    isa      => 'HashRef',
    init_arg => undef,
    builder  => '_hashref'
);

sub _hashref { return {}; };


=head
    $self->uuid_index = { $uuid => { permissions => perm_obj,
                               aliases     => { $user => { $alias => 1 } },
                               md5         => $md5 } }

    $perm_obj = { public => 1 or 0,
                  users => { $user => { read  => 1 or 0,
                                        admin => 1 or 0 } } }

    $user_index = { $user => { aliases => { $alias => $uuid},
                               uuids   => { $uuid  => 1} } }

    $self->alias_index => { $user/$alias => $uuid }
=cut

sub _initArchive {
    my ($self) = @_;
    my $a;
    warn $self->filename ."\n";
    if(-f $self->filename) {
        # If archive already exists, load it
        $a = Archive::Zip->new($self->filename);    
        die "Corrupted database at ".$self->filename unless($a);
        $self->archive($a);
        $self->_load_index();
    } else {
        # Otherwise create new archive, save it
        $a = Archive::Zip->new();
        $a->overwriteAs($self->filename);
        $self->archive($a);
        $self->_save_index();
    }
    return $a;
}

sub has_object {
    my ($self, $args) = @_;

    $self->_update_index();

    my $uuid = $self->_get_uuid($args);

    unless(defined($uuid)) {
        return 0;
    }

    # check permissions
    my $user = $args->{user};
    if (defined($user)) {
        if ($self->user_index->{$user}->{uuids}->{$uuid}) {
            return 1;
        }
    } else {
        if ($self->uuid_index->{$uuid}->{permissions}->{public}) {
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

    my $uuid = $self->_get_uuid($args);

    my $data = _decode($self->archive->contents($uuid));
    return $data;
}

sub save_object {
    my ($self, $args) = @_;

    $self->_update_index();

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

    if (defined($uuid) && defined($self->uuid_index->{$uuid})) {
	# object exists, check if this is the same object
	my $md5 = md5_hex(_encode($object));

	if ($md5 eq $self->uuid_index->{$uuid}->{md5}) {
	    # same, do nothing
	    $self->_save_index();
	    return $uuid;
	} else {
	    # different, create new uuid, update own aliases, copy perms
	    my $perms   = $self->uuid_index->{$uuid}->{permissions};
	    my $aliases = $self->uuid_index->{$uuid}->{aliases};

	    $uuid = Data::UUID->new()->create_str();
	    $object->{uuid} = $uuid;

	    # copy aliases
	    my $new_aliases = {
		$user => {}
	    };

	    foreach my $alias (keys %{$aliases->{$user}}) {
		$self->new_aliases->{$user}->{$alias} = 1;
		$self->alias_index->{$user.'/'.$alias} = $uuid;
		$self->user_index->{$user}->{aliases}->{$alias} = $uuid;
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

	    $self->uuid_index->{$uuid} = {
		permissions => $new_perms,
		aliases => $new_aliases,
		md5 => md5_hex(_encode($object))
	    };

	    $self->user_index->{$user}->{uuids}->{$uuid} = 1;
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

	$self->uuid_index->{$uuid} = {
	    permissions => $perm,
	    aliases => {},
	    md5 => md5_hex(_encode($object))
	};

	$self->user_index->{$user}->{uuids}->{$uuid} = 1;
    }
    $self->archive->addString(_encode($object), $uuid);
    $self->_save_index();

    return $uuid;
}

sub get_user_uuids {
    my ($self, $user) = @_;

    $self->_update_index();

    my @uuids = keys %{$self->user_index->{$user}->{uuids}};

    return \@uuids;
}

sub get_user_aliases {
    my ($self, $user) = @_;

    $self->_update_index();

    my @aliases = keys %{$self->user_index->{$user}->{aliases}};

    return \@aliases;
}

sub add_alias {
    my ($self, $args) = @_;

    $self->_update_index();

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
    if (!$self->user_index->{$user}->{uuids}->{$uuid}) {
	return;
    }

    $self->alias_index->{$user.'/'.$alias} = $uuid;
    $self->uuid_index->{$uuid}->{aliases}->{$user}->{$alias} = 1;
    $self->user_index->{$user}->{aliases}->{$alias} = $uuid;

    $self->_save_index();
}

sub remove_alias {
    my ($self, $args) = @_;

    $self->_update_index();

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
    if (!$self->user_index->{$user}->{uuids}->{$uuid}) {
	return;
    }

    delete $self->alias_index->{$user.'/'.$alias};
    delete $self->uuid_index->{$uuid}->{aliases}->{$user}->{$alias};
    delete $self->user_index->{$user}->{aliases}->{$alias};

    $self->_save_index();
}

sub get_permissions {
    my ($self, $args) = @_;

    $self->_update_index();

    my $uuid = $self->_get_uuid($args);
    my $user = $args->{user};

    unless (defined($uuid) && defined($user)) {
	return;
    }

    # user must have admin permission
    my $perms = $self->uuid_index->{$uuid}->{permissions};
    if ($perms->{users}->{$user}->{admin}) {
	return $perms;
    }
}

sub set_permissions {
    my ($self, $args) = @_;

    $self->_update_index();

    my $uuid = $self->_get_uuid($args);
    my $user = $args->{user};
    my $perms = $args->{permissions};

    unless (defined($uuid) && defined($user) && defined($perms)) {
	return;
    }

    # user must have admin permission
    my $old_perms = $self->uuid_index->{$uuid}->{permissions};
    unless ($old_perms->{users}->{$user}->{admin}) {
	return;
    }

    # should make sure new perms have an admin user


    $self->uuid_index->{$uuid}->{permissions} = $perms;

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
	$self->user_index->{$new_user}->{uuids}->{$uuid} = 1;
    }

    foreach my $old_user (keys %$old_users) {
	$self->delete_object({ user => $old_user, uuid => $uuid });
    }

    $self->_save_index();
}

# not working
sub delete_object {
    my ($self, $args) = @_;

    $self->_update_index();

    my $uuid = $self->_get_uuid($args);
    my $user = $args->{user};

    unless (defined($uuid) && defined($user)) {
	return;
    }

    unless($self->user_index->{$user}->{uuids}->{$uuid}) {
	return;
    }

    # remove the aliases
    foreach my $alias (keys %{$self->uuid_index->{$uuid}->{aliases}->{$user}}) {
	$self->remove_alias({ user => $user, uuid => $uuid, alias => $alias });
    }

    # remove user permissions on object
    delete $self->uuid_index->{$uuid}->{permissions}->{users}->{$user};
    delete $self->user_index->{$user}->{uuids}->{$uuid};

    # remove if no users in permissions
    if (scalar keys %{$self->uuid_index->{$uuid}->{permissions}->{users}} == 0) {
	unlink $uuid or die "Could not delete file $uuid: $!";
	delete $self->uuid_index->{$uuid};
    }

    $self->_save_index();
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
    my ($self, $args) = @_;

    my $uuid = $args->{uuid};
    my $user_alias = $args->{user_alias};

    if (defined($uuid)) {
        return $uuid;
    } elsif (defined($user_alias)) {
        # find uuid for alias
        my $id = $self->alias_index->{$user_alias};
        if (defined($id)) {
            return $id;
        }
    }
}

sub _load_index {
    my ($self) = @_;
    my $indexes = _decode($self->archive->contents($INDEX_FILENAME));
    $self->uuid_index($indexes->{uuid_index});
    $self->user_index($indexes->{user_index});
    $self->alias_index($indexes->{alias_index});
    $self->loaded(1);
}

sub _save_index {
    my ($self) = @_;
    my $indexes = {
        uuid_index  => $self->uuid_index,
        user_index  => $self->user_index,
        alias_index => $self->alias_index,
    };
    $self->_update_archive_member($INDEX_FILENAME, _encode($indexes));
}

sub _update_archive_member {
    my ($self, $name, $data) = @_;
    # TODO - locking
    if($self->archive->memberNamed($name)) {
        $self->archive->contents($name, $data);
    } else {
        $self->archive->addString($data, $name);
    }
    $self->archive->overwriteAs($self->filename);
    # TODO - unlocking
}

sub _update_index {
    my ($self) = @_;
}


no Moose;
__PACKAGE__->meta->make_immutable;
