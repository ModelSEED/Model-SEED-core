#
# Subtypes for ModelSEED::MS::ModelAnalysisModel
#
package ModelSEED::MS::Types::ModelAnalysisModel;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ModelAnalysisModel;

coerce 'ModelSEED::MS::ModelAnalysisModel',
    from 'HashRef',
    via { ModelSEED::MS::DB::ModelAnalysisModel->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfModelAnalysisModel',
    as 'ArrayRef[ModelSEED::MS::ModelAnalysisModel]';
coerce 'ModelSEED::MS::ArrayRefOfModelAnalysisModel',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ModelAnalysisModel->new( $_ ) } @{$_} ] };

1;
