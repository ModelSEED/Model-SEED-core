package ModelSEED::MS::MediaCompound;
use Moose;
use namespace::autoclean;
use Carp;

# Constants
has _type => (is => 'rw', isa => 'Str', default => 'MediaCompound');

# Attributes
has biochemistry =>
    (is => 'rw', isa => 'ModelSEED::MS::Biochemistry', weak_ref => 1);
has compound_uuid => (is => 'rw', isa => 'Str', required => 1);
has concentration => (is => 'rw', isa => 'Num', default  => 1);
has minflux       => (is => 'rw', isa => 'Num', default  => -100);
has maxflux       => (is => 'rw', isa => 'Num', default  => 100);

# Subobjects

has compound      => (
    is       => 'rw',
    isa      => 'ModelSEED::MS::Compound',
    lazy     => 1,
    builder  => '_buildCompound',
    weak_ref => 1
);

sub BUILDARGS {
    my ($self, $params) = @_;
    my $attr = $params->{attributes};
    my $rels = $params->{relationships};
    if (defined($attr)) {
        map { $params->{$_} = $attr->{$_} }
            grep { defined($attr->{$_}) } keys %$attr;
        delete $params->{attributes};
    }
    # Here we build the compound if it is supplied directly.
    if (  !defined($params->{biochemistry})
        && defined($params->{relationships}->{compound}))
    {
        $params->{compound} = ModelSEED::MS::Compound->new(
            $params->{relationships}->{compound});
    }
    return $params;
}

sub _buildCompound {
    my $self = shift @_;
    if (defined($self->biochemistry)) {
        my $cpd = $self->biochemistry->getCompound(
            {uuid => $self->compound_uuid});
        die "UnknownObject " . $self->compound_uuid
            unless defined($cpd);
        return $cpd;
    } else {
        confess "No Biochemistry";
    }
}

sub serializeToDB {
    my ($self) = @_;
    return {
        type       => $self->_type,
        attributes => {
            compound_uuid => $self->compound_uuid,
            concentration => $self->concentration,
            minflux       => $self->minflux,
            maxflux       => $self->maxflux,
        },
        relationships => {}
    };
}

__PACKAGE__->meta->make_immutable;
1;
