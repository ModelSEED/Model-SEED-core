#
# Subtypes for ModelSEED::MS::ExperimentDataPoint
#
package ModelSEED::MS::Types::ExperimentDataPoint;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::ExperimentDataPoint;

coerce 'ModelSEED::MS::DB::ExperimentDataPoint',
    from 'HashRef',
    via { ModelSEED::MS::DB::ExperimentDataPoint->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfExperimentDataPoint',
    as 'ArrayRef[ModelSEED::MS::DB::ExperimentDataPoint]';
coerce 'ModelSEED::MS::ArrayRefOfExperimentDataPoint',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::ExperimentDataPoint->new( $_ ) } @{$_} ] };

1;
