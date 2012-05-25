#
# Subtypes for ModelSEED::MS::ModelAnalysisAnnotation
#
package ModelSEED::MS::Types::ModelAnalysisAnnotation;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ModelAnalysisAnnotation;

coerce 'ModelSEED::MS::ModelAnalysisAnnotation',
    from 'HashRef',
    via { ModelSEED::MS::DB::ModelAnalysisAnnotation->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfModelAnalysisAnnotation',
    as 'ArrayRef[ModelSEED::MS::ModelAnalysisAnnotation]';
coerce 'ModelSEED::MS::ArrayRefOfModelAnalysisAnnotation',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ModelAnalysisAnnotation->new( $_ ) } @{$_} ] };

1;
