#
# Subtypes for ModelSEED::MS::GfSolutionReactionGeneCandidate
#
package ModelSEED::MS::Types::GfSolutionReactionGeneCandidate;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::GfSolutionReactionGeneCandidate;

coerce 'ModelSEED::MS::GfSolutionReactionGeneCandidate',
    from 'HashRef',
    via { ModelSEED::MS::DB::GfSolutionReactionGeneCandidate->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfGfSolutionReactionGeneCandidate',
    as 'ArrayRef[ModelSEED::MS::GfSolutionReactionGeneCandidate]';
coerce 'ModelSEED::MS::ArrayRefOfGfSolutionReactionGeneCandidate',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::GfSolutionReactionGeneCandidate->new( $_ ) } @{$_} ] };

1;
