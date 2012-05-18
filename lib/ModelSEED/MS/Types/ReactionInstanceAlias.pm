#
# Subtypes for ModelSEED::MS::ReactionInstanceAlias
#
package ModelSEED::MS::Types::ReactionInstanceAlias;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ReactionInstanceAlias;

coerce 'ModelSEED::MS::ReactionInstanceAlias',
    from 'HashRef',
    via { ModelSEED::MS::DB::ReactionInstanceAlias->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfReactionInstanceAlias',
    as 'ArrayRef[ModelSEED::MS::ReactionInstanceAlias]';
coerce 'ModelSEED::MS::ArrayRefOfReactionInstanceAlias',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ReactionInstanceAlias->new( $_ ) } @{$_} ] };

1;
