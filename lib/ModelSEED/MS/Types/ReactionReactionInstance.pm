#
# Subtypes for ModelSEED::MS::ReactionReactionInstance
#
package ModelSEED::MS::Types::ReactionReactionInstance;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ReactionReactionInstance;

coerce 'ModelSEED::MS::ReactionReactionInstance',
    from 'HashRef',
    via { ModelSEED::MS::DB::ReactionReactionInstance->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfReactionReactionInstance',
    as 'ArrayRef[ModelSEED::MS::ReactionReactionInstance]';
coerce 'ModelSEED::MS::ArrayRefOfReactionReactionInstance',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ReactionReactionInstance->new( $_ ) } @{$_} ] };

1;
