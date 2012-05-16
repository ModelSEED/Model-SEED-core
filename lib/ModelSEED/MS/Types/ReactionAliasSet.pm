#
# Subtypes for ModelSEED::MS::ReactionAliasSet
#
package ModelSEED::MS::Types::ReactionAliasSet;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::ReactionAliasSet;

coerce 'ModelSEED::MS::DB::ReactionAliasSet',
    from 'HashRef',
    via { ModelSEED::MS::DB::ReactionAliasSet->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfReactionAliasSet',
    as 'ArrayRef[ModelSEED::MS::DB::ReactionAliasSet]';
coerce 'ModelSEED::MS::ArrayRefOfReactionAliasSet',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::ReactionAliasSet->new( $_ ) } @{$_} ] };

1;
