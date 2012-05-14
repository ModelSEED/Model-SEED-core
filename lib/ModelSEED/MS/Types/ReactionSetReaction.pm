#
# Subtypes for ModelSEED::MS::ReactionSetReaction
#
package ModelSEED::MS::Types::ReactionSetReaction;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::ReactionSetReaction;

coerce 'ModelSEED::MS::DB::ReactionSetReaction',
    from 'HashRef',
    via { ModelSEED::MS::DB::ReactionSetReaction->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfReactionSetReaction',
    as 'ArrayRef[ModelSEED::MS::DB::ReactionSetReaction]';
coerce 'ModelSEED::MS::ArrayRefOfReactionSetReaction',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::ReactionSetReaction->new( $_ ) } @{$_} ] };

1;
