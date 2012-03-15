package ModelSEED::FileDB::FileIndex;

use strict;
use warnings;

use JSON::Any;
use File::stat;

use Moose;
use Data::UUID;

has filename => (is => 'rw', isa => 'Str', required => 1);

my $filename;
my $loaded = 0;
my $mod_time = 0;
my $index;

sub BUILD {
    my ($self) = @_;

    $filename = $self->filename;

    print STDERR "Building...\n";
    # check if the file exists, if not then create it
    if (!-e $filename) {
	print STDERR "Creating file...\n";
	open FILE, ">$filename"
	    or die "Couldn't open file '$filename': $!";
	print FILE "{}";
	close FILE;
    }
}

sub has_object {
    my ($self, $args) = @_;

    _update_index();

    if (!defined($args->{user})) {
	$args->{user} = 'public';
    }

    if (defined(_get_uuid($args))) {
	return 1;
    } else {
	return 0;
    }
}

# get_object with uuid or user/name
sub get_object {
    my ($self, $args) = @_;

    _update_index();

    if (!defined($args->{user})) {
	$args->{user} = 'public';
    }

    my $uuid = _get_uuid($args);

    unless(defined($uuid)) {
	return;
    }

    open FILE, "<$uuid";
    my $data = JSON::Any->decode(<FILE>);
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

    my $uuid = $args->{object}->{uuid};
    if (!defined($uuid)) {
	$uuid = Data::UUID->new()->create_str();
    } elsif (!defined($index->{$args->{user}}->{uuid}->{$uuid})) {
	# object doesn't exist, add with current uuid
    } elsif ($index->{$args->{user}}->{uuid}->{$uuid}->{write}) {
	# user has write permission
	$uuid = Data::UUID->new()->create_str();
    } else {
	return;
    }

    $args->{object}->{uuid} = $uuid;

    open FILE, ">$uuid";
    print FILE JSON::Any->encode($args->{object});
    close FILE;

    # add permissions to object
    $index->{$args->{user}}->{uuid}->{$uuid} = {
	read  => 1,
	write => 1,
	admin => 1
    };

    _save_index();

    return $uuid;
}

sub get_uuids_for_user {
    my ($self, $user) = @_;

    _update_index();

    my @uuids = keys %{$index->{$user}->{uuid}};

    return \@uuids;
}

sub get_aliases_for_user {
    my ($self, $user) = @_;

    _update_index();

    my @aliases = keys %{$index->{$user}->{alias}};

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

    # user must be able to read object
    if (!$index->{$args->{user}}->{uuid}->{$args->{uuid}}->{read}) {
	return;
    }

    $index->{$args->{user}}->{alias}->{$args->{alias}} = $args->{uuid};

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

    # user must be able to read object
    if (!$index->{$args->{user}}->{uuid}->{$args->{uuid}}->{read}) {
	return;
    }

    delete $index->{$args->{user}}->{alias}->{$args->{alias}};

    _save_index();
}

sub add_user {
    my ($self, $user) = @_;

    _update_index();

    if (!defined($index->{$user})) {
	$index->{$user} = {
	    uuid  => {},
	    alias => {}
	};

	_save_index();
    }
}

sub remove_user {
    my ($self, $user) = @_;

    _update_index();

    if (defined($index->{$user})) {
	delete $index->{$user};

	_save_index();
    }
}

sub change_permissions {
    my ($self, $args) = @_;

    _update_index();

    # args must be: admin, user, uuid, permissions, 
    foreach my $arg (qw(admin user uuid permissions)) {
	if (!defined($args->{$arg})) {
	    # TODO: error
	    return;
	}
    }

    # 'admin' user must have admin permission
    if (!$index->{$args->{admin}}->{uuid}->{$args->{uuid}}->{admin}) {
	return;
    }

    $index->{$args->{user}}->{uuid}->{$args->{uuid}} = $args->{permissions};

    _save_index();
}

# not working
sub delete_object {
    my ($self, $uuid) = @_;

    _update_index();

    unlink $uuid or die "Could not delete file $uuid: $!";

    _save_index();
}

# parses the arguments from has_object and get_object
# and checks if the user has the correct permissions
# returns the uuid, or 0 if not found/wrong permissions
sub _get_uuid {
    my ($args) = @_;

    my $uuid  = $args->{uuid};
    my $user  = $args->{user};
    my $alias = $args->{alias};

    if (defined($alias)) {
	# find uuid for alias
	my $id = $index->{$user}->{alias}->{$alias};
	if (defined($id)) {
	    $uuid = $id;
	} else {
	    return;
	}
    }

    if (defined($index->{$user}->{uuid}->{$uuid})) {
	return $uuid;
    }
}

sub _load_index {
    print STDERR "Loading...\n";

    open FILE, "<$filename"
	or die "Couldn't open file '$filename': $!";
    $index = JSON::Any->decode(<FILE>);
    close FILE;

    $loaded = 1;

    return $index;
}

sub _save_index {
    print STDERR "Saving...\n";

    open FILE, ">$filename"
	or die "Couldn't open file '$filename': $!";
    print FILE JSON::Any->encode($index);
    close FILE;

    # update the mod time
    $mod_time = _get_mod_time();
}

sub _update_index {
    my ($self) = @_;

    print STDERR "Updating...\n";
    if (!$loaded || $mod_time != _get_mod_time()) {
	_load_index();
    }
}

sub _get_mod_time {
    return stat($filename)->mtime;
}

no Moose;
__PACKAGE__->meta->make_immutable;
