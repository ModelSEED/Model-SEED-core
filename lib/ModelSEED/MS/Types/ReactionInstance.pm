#
# Subtypes for ModelSEED::MS::ReactionInstance
#
package ModelSEED::MS::Types::ReactionInstance;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ReactionInstance;

coerce 'ModelSEED::MS::ReactionInstance',
    from 'HashRef',
    via { ModelSEED::MS::DB::ReactionInstance->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfReactionInstance',
    as 'ArrayRef[ModelSEED::MS::ReactionInstance]';
coerce 'ModelSEED::MS::ArrayRefOfReactionInstance',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ReactionInstance->new( $_ ) } @{$_} ] };

1;
