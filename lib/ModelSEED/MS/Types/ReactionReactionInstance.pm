#
# Subtypes for ModelSEED::MS::ReactionReactionInstance
#
package ModelSEED::MS::Types::ReactionReactionInstance;
use Moose::Util::TypeConstraints;
use Class::Autouse qw ( ModelSEED::MS::DB::ReactionReactionInstance );

coerce 'ModelSEED::MS::ReactionReactionInstance',
    from 'HashRef',
    via { ModelSEED::MS::DB::ReactionReactionInstance->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfReactionReactionInstance',
    as 'ArrayRef[ModelSEED::MS::DB::ReactionReactionInstance]';
coerce 'ModelSEED::MS::ArrayRefOfReactionReactionInstance',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::ReactionReactionInstance->new( $_ ) } @{$_} ] };

1;
