# Holder for ModelSEED::MS::ExperimentDataPoint
package ModelSEED::MS::LazyHolder::ExperimentDataPoint;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ExperimentDataPoint;
use ModelSEED::MS::Types::ExperimentDataPoint;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ExperimentDataPoint::Lazy',
        as 'ModelSEED::MS::LazyHolder::ExperimentDataPoint';
    coerce 'ModelSEED::MS::ExperimentDataPoint::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ExperimentDataPoint->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfExperimentDataPoint',
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

