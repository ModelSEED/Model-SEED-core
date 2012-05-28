#
# Subtypes for ModelSEED::MS::ExperimentDataPoint
#
package ModelSEED::MS::Types::ExperimentDataPoint;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ExperimentDataPoint;

coerce 'ModelSEED::MS::ExperimentDataPoint',
    from 'HashRef',
    via { ModelSEED::MS::DB::ExperimentDataPoint->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfExperimentDataPoint',
    as 'ArrayRef[ModelSEED::MS::ExperimentDataPoint]';
coerce 'ModelSEED::MS::ArrayRefOfExperimentDataPoint',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ExperimentDataPoint->new( $_ ) } @{$_} ] };

1;
