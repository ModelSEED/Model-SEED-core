#
# Subtypes for ModelSEED::MS::ModelAnalysisMapping
#
package ModelSEED::MS::Types::ModelAnalysisMapping;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ModelAnalysisMapping;

coerce 'ModelSEED::MS::ModelAnalysisMapping',
    from 'HashRef',
    via { ModelSEED::MS::DB::ModelAnalysisMapping->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfModelAnalysisMapping',
    as 'ArrayRef[ModelSEED::MS::ModelAnalysisMapping]';
coerce 'ModelSEED::MS::ArrayRefOfModelAnalysisMapping',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ModelAnalysisMapping->new( $_ ) } @{$_} ] };

1;
