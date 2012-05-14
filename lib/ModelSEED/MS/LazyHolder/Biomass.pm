# Holder for ModelSEED::MS::Biomass
package ModelSEED::MS::LazyHolder::Biomass;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Biomass;
use ModelSEED::MS::Types::Biomass;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::Biomass::Lazy',
        as 'ModelSEED::MS::LazyHolder::Biomass';
    coerce 'ModelSEED::MS::Biomass::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::Biomass->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfBiomass',
    lazy    => 1,
    coerce  => 1,
    builder => '_build'
);

sub _build {
    my ($self) = @_; 
    my $val = $self->uncoerced;
    $self->uncoerced(undef);
    return $val;
}
__PACKAGE__->meta->make_immutable;
1;

