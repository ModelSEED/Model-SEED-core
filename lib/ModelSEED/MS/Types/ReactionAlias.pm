#
# Subtypes for ModelSEED::MS::ReactionAlias
#
package ModelSEED::MS::Types::ReactionAlias;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ReactionAlias;

coerce 'ModelSEED::MS::ReactionAlias',
    from 'HashRef',
    via { ModelSEED::MS::DB::ReactionAlias->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfReactionAlias',
    as 'ArrayRef[ModelSEED::MS::ReactionAlias]';
coerce 'ModelSEED::MS::ArrayRefOfReactionAlias',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ReactionAlias->new( $_ ) } @{$_} ] };

1;
