#
# Subtypes for ModelSEED::MS::Experiment
#
package ModelSEED::MS::Types::Experiment;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::Experiment;

coerce 'ModelSEED::MS::DB::Experiment',
    from 'HashRef',
    via { ModelSEED::MS::DB::Experiment->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfExperiment',
    as 'ArrayRef[ModelSEED::MS::DB::Experiment]';
coerce 'ModelSEED::MS::ArrayRefOfExperiment',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::Experiment->new( $_ ) } @{$_} ] };

1;
