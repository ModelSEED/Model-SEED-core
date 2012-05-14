#
# Subtypes for ModelSEED::MS::ReactionInstanceAlias
#
package ModelSEED::MS::Types::ReactionInstanceAlias;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::ReactionInstanceAlias;

coerce 'ModelSEED::MS::DB::ReactionInstanceAlias',
    from 'HashRef',
    via { ModelSEED::MS::DB::ReactionInstanceAlias->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfReactionInstanceAlias',
    as 'ArrayRef[ModelSEED::MS::DB::ReactionInstanceAlias]';
coerce 'ModelSEED::MS::ArrayRefOfReactionInstanceAlias',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::ReactionInstanceAlias->new( $_ ) } @{$_} ] };

1;
