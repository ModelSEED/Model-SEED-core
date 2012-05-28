package ModelSEED::FileDBold::FileDB;

use Moose;
use Moose::Util::TypeConstraints;
use Cwd qw(abs_path);
use File::Path qw(make_path);
use ModelSEED::FileDBold::FileIndex;

#with 'ModelSEED::Database';

subtype 'Directory',
    as 'Str',
    where {
	if (!-d abs_path($_)) {
	    make_path($_) or return 0;
	}

	return 1;
    };


has directory => (
    is       => 'ro',
    isa      => 'Directory',
    required => 1
);

has indexes => (
    is      => 'ro',
    isa     => 'HashRef',
    builder => '_buildIndicies',
    lazy    => 1
);

has user_index => (
    is      => 'ro',
    isa     => 'ModelSEED::FileDBold::FileIndex',
    builder => '_buildUserIndex'
);

has types => (
    is      => 'ro',
    isa     => 'ArrayRef[Str]',
    builder => '_buildTypes',
    lazy    => 1
);

sub _buildTypes {
    return [ qw( Model Biochemistry Mapping Annotation ) ];
}

sub _buildIndicies {
    my $self = shift @_;
    my $indexes = {};
    foreach my $type (@{$self->types}) {
        $indexes->{$type} = ModelSEED::FileDBold::FileIndex->new({
            filename => $self->directory . "/" . $type
        });
    }
    return $indexes;
}

sub _buildUserIndex {
    my ($self) = @_;
    return ModelSEED::FileDBold::FileIndex->new({
	filename => $self->directory . "/Users"
    });
}

sub has_object {
    my ($self, $type, $args) = @_;

    return $self->indexes->{$type}->has_object($args);
}

sub get_object {
    my ($self, $type, $args) = @_;
    return $self->indexes->{$type}->get_object($args);
}

sub save_object {
    my ($self, $type, $args) = @_;
    return $self->indexes->{$type}->save_object($args);
}

sub delete_object {
    my ($self, $type, $args) = @_;
    return $self->indexes->{$type}->delete_object($args);
}

sub set_alias {
    my ($self, $type, $args) = @_;
    return $self->indexes->{$type}->set_alias($args);
}

sub remove_alias {
    my ($self, $type, $args) = @_;
    return $self->indexes->{$type}->remove_alias($args);
}

sub get_permissions {
    my ($self, $type, $args) = @_;
    return $self->indexes->{$type}->get_permissions($args);
}

sub set_permissions {
    my ($self, $type, $args) = @_;
    return $self->indexes->{$type}->set_permissions($args);
}

sub get_user_uuids {
    my ($self, $type, $user) = @_;
    return $self->indexes->{$type}->get_user_uuids($user);
}

sub get_user_aliases {
    my ($self, $type, $user) = @_;
    return $self->indexes->{$type}->get_user_aliases($user);
}

sub add_user {
    my ($self, $user_obj) = @_;

    # args must be at least: login, password
    foreach my $arg (qw(login password)) {
	if (!defined($user_obj->{$arg})) {
	    # TODO: error
	    return 0;
	}
    }

    # make sure user doesn't exist
    if (defined($self->get_user($user_obj->{login}))) {
	print STDERR "Error: user already exists\n";
	return 0;
    }


    # crypt the password
    my $pass = $user_obj->{password};
    my $salt = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];

    $user_obj->{password} = crypt($pass, $salt);

    my $uuid = $self->user_index->save_object({
	user => $user_obj->{login},
	object => $user_obj
    });

    $self->user_index->set_alias({
	user => $user_obj->{login},
	uuid => $uuid,
	alias => 'user'
    });

    return 1;
}

sub get_user {
    my ($self, $user) = @_;

    return $self->user_index->get_object({ user => $user, user_alias => $user . '/user' });
}

sub authenticate_user {
    my ($self, $user, $pass) = @_;

    my $user_obj = $self->user_index->get_object({ user => $user, user_alias => $user . '/user' });

    unless (defined($user_obj)) {
	return 0;
    }

    if (crypt($pass, $user_obj->{password}) eq $user_obj->{password}) {
	return 1;
    } else {
	return 0;
    }
}

sub remove_user {
    my ($self, $user_obj) = @_;

    # TODO: implement
}

no Moose;
__PACKAGE__->meta->make_immutable;
