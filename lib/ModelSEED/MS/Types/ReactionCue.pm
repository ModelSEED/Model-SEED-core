#
# Subtypes for ModelSEED::MS::ReactionCue
#
package ModelSEED::MS::Types::ReactionCue;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ReactionCue;

coerce 'ModelSEED::MS::ReactionCue',
    from 'HashRef',
    via { ModelSEED::MS::DB::ReactionCue->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfReactionCue',
    as 'ArrayRef[ModelSEED::MS::ReactionCue]';
coerce 'ModelSEED::MS::ArrayRefOfReactionCue',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ReactionCue->new( $_ ) } @{$_} ] };

1;
