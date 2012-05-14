#
# Subtypes for ModelSEED::MS::ReactionInstance
#
package ModelSEED::MS::Types::ReactionInstance;
use Moose::Util::TypeConstraints;
use Class::Autouse qw ( ModelSEED::MS::DB::ReactionInstance );

coerce 'ModelSEED::MS::ReactionInstance',
    from 'HashRef',
    via { ModelSEED::MS::DB::ReactionInstance->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfReactionInstance',
    as 'ArrayRef[ModelSEED::MS::DB::ReactionInstance]';
coerce 'ModelSEED::MS::ArrayRefOfReactionInstance',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::ReactionInstance->new( $_ ) } @{$_} ] };

1;
