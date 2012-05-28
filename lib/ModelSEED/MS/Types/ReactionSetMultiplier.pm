#
# Subtypes for ModelSEED::MS::ReactionSetMultiplier
#
package ModelSEED::MS::Types::ReactionSetMultiplier;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ReactionSetMultiplier;

coerce 'ModelSEED::MS::ReactionSetMultiplier',
    from 'HashRef',
    via { ModelSEED::MS::DB::ReactionSetMultiplier->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfReactionSetMultiplier',
    as 'ArrayRef[ModelSEED::MS::ReactionSetMultiplier]';
coerce 'ModelSEED::MS::ArrayRefOfReactionSetMultiplier',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ReactionSetMultiplier->new( $_ ) } @{$_} ] };

1;
