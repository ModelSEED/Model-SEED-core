#
# Subtypes for ModelSEED::MS::ReactionSetReaction
#
package ModelSEED::MS::Types::ReactionSetReaction;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ReactionSetReaction;

coerce 'ModelSEED::MS::ReactionSetReaction',
    from 'HashRef',
    via { ModelSEED::MS::DB::ReactionSetReaction->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfReactionSetReaction',
    as 'ArrayRef[ModelSEED::MS::ReactionSetReaction]';
coerce 'ModelSEED::MS::ArrayRefOfReactionSetReaction',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ReactionSetReaction->new( $_ ) } @{$_} ] };

1;
