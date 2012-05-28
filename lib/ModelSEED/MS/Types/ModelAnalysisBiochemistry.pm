#
# Subtypes for ModelSEED::MS::ModelAnalysisBiochemistry
#
package ModelSEED::MS::Types::ModelAnalysisBiochemistry;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ModelAnalysisBiochemistry;

coerce 'ModelSEED::MS::ModelAnalysisBiochemistry',
    from 'HashRef',
    via { ModelSEED::MS::DB::ModelAnalysisBiochemistry->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfModelAnalysisBiochemistry',
    as 'ArrayRef[ModelSEED::MS::ModelAnalysisBiochemistry]';
coerce 'ModelSEED::MS::ArrayRefOfModelAnalysisBiochemistry',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ModelAnalysisBiochemistry->new( $_ ) } @{$_} ] };

1;
