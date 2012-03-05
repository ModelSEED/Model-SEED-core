package ModelSEED::MS::Compartment;
use Moose;
use ModelSEED::utilities;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use Data::UUID;
use DateTime;

# Attributes

has 'uuid'    => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildUUID');
has 'modDate' => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildDate');
has 'id'      => (is => 'rw', isa => 'Str', required => 1);
has 'locked'  => (is => 'rw', isa => 'Int', default  => 0);
has 'name'    => (is => 'rw', isa => 'Str', required => 1);
has '_type'   => (is => 'ro', isa => 'Str', init_arg => undef, default => 'Compartment');

sub BUILDARGS {
    my ($self, $params) = @_;
    my $attr = $params->{attributes};
    if(defined($attr)) {
        map { $params->{$_} = $attr->{$_} } grep { defined($attr->{$_}) } keys %$attr;
        delete $params->{attributes};
    }
    return $params;
}

sub serializeToDB {
    my ($self) = @_;
    return {
        attributes => {
            uuid    => $self->uuid,
            modDate => $self->modDate,
            id      => $self->id,
            locked  => $self->locked,
            name    => $self->name,
        },
        relationships => {},
        type          => $self->_type,
    };
}

sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildDate { return DateTime->now( time_zone => 'floating' )->datetime; }

__PACKAGE__->meta->make_immutable;
1;
