#
# Subtypes for ModelSEED::MS::ComplexReactionInstance
#
package ModelSEED::MS::Types::ComplexReactionInstance;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ComplexReactionInstance;

coerce 'ModelSEED::MS::ComplexReactionInstance',
    from 'HashRef',
    via { ModelSEED::MS::DB::ComplexReactionInstance->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfComplexReactionInstance',
    as 'ArrayRef[ModelSEED::MS::ComplexReactionInstance]';
coerce 'ModelSEED::MS::ArrayRefOfComplexReactionInstance',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ComplexReactionInstance->new( $_ ) } @{$_} ] };

1;
