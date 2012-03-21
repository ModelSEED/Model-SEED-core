package ModelSEED::FileDB;
use Moose;
use Moose::Util::TypeConstraints;
use Cwd qw(abs_path);
use ModelSEED::FileDB::FileIndex;

subtype 'Directory',
    as 'Str',
    where { -d abs_path($_) };


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
has types => (
    is      => 'ro',
    isa     => 'ArrayRef[Str]',
    builder => '_buildTypes',
    lazy    => 1
);

sub _buildTypes {
    return [ qw( model biochemistry mapping annotation ) ];
}

sub _buildIndicies {
    my $self = shift @_;
    my $indexes = {};
    foreach my $type (@{$self->types}) {
        $indexes->{$type} = ModelSEED::FileDB::FileIndex->new(
            {filename => $self->directory . "/" . $type . ".zip"});
    }
    return $indexes;
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

sub add_alias {
    my ($self, $type, $args) = @_;
    return $self->indexes->{$type}->add_alias($args);
}

sub remove_alias {
    my ($self, $type, $args) = @_;
    return $self->indexes->{$type}->remove_alias($args);
}

sub change_permissions {
    my ($self, $type, $args) = @_;
    return $self->indexes->{$type}->change_permissions($args);
}

sub get_uuids_for_user {
    my ($self, $type, $user) = @_;
    return $self->indexes->{$type}->get_uuids_for_user($user);
}

sub get_aliases_for_user {
    my ($self, $type, $user) = @_;
    return $self->indexes->{$type}->get_aliases_for_user($user);
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
