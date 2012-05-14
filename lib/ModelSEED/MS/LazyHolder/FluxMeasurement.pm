# Holder for ModelSEED::MS::FluxMeasurement
package ModelSEED::MS::LazyHolder::FluxMeasurement;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FluxMeasurement;
use ModelSEED::MS::Types::FluxMeasurement;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::FluxMeasurement::Lazy',
        as 'ModelSEED::MS::LazyHolder::FluxMeasurement';
    coerce 'ModelSEED::MS::FluxMeasurement::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::FluxMeasurement->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfFluxMeasurement',
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

