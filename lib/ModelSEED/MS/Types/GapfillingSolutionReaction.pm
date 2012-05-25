#
# Subtypes for ModelSEED::MS::GapfillingSolutionReaction
#
package ModelSEED::MS::Types::GapfillingSolutionReaction;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::GapfillingSolutionReaction;

coerce 'ModelSEED::MS::GapfillingSolutionReaction',
    from 'HashRef',
    via { ModelSEED::MS::DB::GapfillingSolutionReaction->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfGapfillingSolutionReaction',
    as 'ArrayRef[ModelSEED::MS::GapfillingSolutionReaction]';
coerce 'ModelSEED::MS::ArrayRefOfGapfillingSolutionReaction',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::GapfillingSolutionReaction->new( $_ ) } @{$_} ] };

1;
