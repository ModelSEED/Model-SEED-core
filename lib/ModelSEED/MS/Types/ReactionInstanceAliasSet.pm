#
# Subtypes for ModelSEED::MS::ReactionInstanceAliasSet
#
package ModelSEED::MS::Types::ReactionInstanceAliasSet;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::ReactionInstanceAliasSet;

coerce 'ModelSEED::MS::DB::ReactionInstanceAliasSet',
    from 'HashRef',
    via { ModelSEED::MS::DB::ReactionInstanceAliasSet->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfReactionInstanceAliasSet',
    as 'ArrayRef[ModelSEED::MS::DB::ReactionInstanceAliasSet]';
coerce 'ModelSEED::MS::ArrayRefOfReactionInstanceAliasSet',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::ReactionInstanceAliasSet->new( $_ ) } @{$_} ] };

1;
