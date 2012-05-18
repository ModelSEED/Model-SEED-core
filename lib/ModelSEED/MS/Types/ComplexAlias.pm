#
# Subtypes for ModelSEED::MS::ComplexAlias
#
package ModelSEED::MS::Types::ComplexAlias;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ComplexAlias;

coerce 'ModelSEED::MS::ComplexAlias',
    from 'HashRef',
    via { ModelSEED::MS::DB::ComplexAlias->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfComplexAlias',
    as 'ArrayRef[ModelSEED::MS::ComplexAlias]';
coerce 'ModelSEED::MS::ArrayRefOfComplexAlias',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ComplexAlias->new( $_ ) } @{$_} ] };

1;
