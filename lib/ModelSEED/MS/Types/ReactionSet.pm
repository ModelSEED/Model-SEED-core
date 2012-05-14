#
# Subtypes for ModelSEED::MS::ReactionSet
#
package ModelSEED::MS::Types::ReactionSet;
use Moose::Util::TypeConstraints;
use Class::Autouse qw ( ModelSEED::MS::DB::ReactionSet );

coerce 'ModelSEED::MS::ReactionSet',
    from 'HashRef',
    via { ModelSEED::MS::DB::ReactionSet->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfReactionSet',
    as 'ArrayRef[ModelSEED::MS::DB::ReactionSet]';
coerce 'ModelSEED::MS::ArrayRefOfReactionSet',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::ReactionSet->new( $_ ) } @{$_} ] };

1;
