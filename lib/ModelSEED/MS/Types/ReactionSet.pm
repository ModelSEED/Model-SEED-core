#
# Subtypes for ModelSEED::MS::ReactionSet
#
package ModelSEED::MS::Types::ReactionSet;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ReactionSet;

coerce 'ModelSEED::MS::ReactionSet',
    from 'HashRef',
    via { ModelSEED::MS::DB::ReactionSet->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfReactionSet',
    as 'ArrayRef[ModelSEED::MS::ReactionSet]';
coerce 'ModelSEED::MS::ArrayRefOfReactionSet',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ReactionSet->new( $_ ) } @{$_} ] };

1;
