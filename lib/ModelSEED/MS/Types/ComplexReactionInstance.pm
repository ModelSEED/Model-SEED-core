#
# Subtypes for ModelSEED::MS::ComplexReactionInstance
#
package ModelSEED::MS::Types::ComplexReactionInstance;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::ComplexReactionInstance;

coerce 'ModelSEED::MS::DB::ComplexReactionInstance',
    from 'HashRef',
    via { ModelSEED::MS::DB::ComplexReactionInstance->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfComplexReactionInstance',
    as 'ArrayRef[ModelSEED::MS::DB::ComplexReactionInstance]';
coerce 'ModelSEED::MS::ArrayRefOfComplexReactionInstance',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::ComplexReactionInstance->new( $_ ) } @{$_} ] };

1;
