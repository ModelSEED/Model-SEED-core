#
# Subtypes for ModelSEED::MS::ReactionAlias
#
package ModelSEED::MS::Types::ReactionAlias;
use Moose::Util::TypeConstraints;
use Class::Autouse qw ( ModelSEED::MS::DB::ReactionAlias );

coerce 'ModelSEED::MS::ReactionAlias',
    from 'HashRef',
    via { ModelSEED::MS::DB::ReactionAlias->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfReactionAlias',
    as 'ArrayRef[ModelSEED::MS::DB::ReactionAlias]';
coerce 'ModelSEED::MS::ArrayRefOfReactionAlias',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::ReactionAlias->new( $_ ) } @{$_} ] };

1;
