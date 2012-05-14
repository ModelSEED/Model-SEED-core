#
# Subtypes for ModelSEED::MS::ComplexAlias
#
package ModelSEED::MS::Types::ComplexAlias;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::ComplexAlias;

coerce 'ModelSEED::MS::DB::ComplexAlias',
    from 'HashRef',
    via { ModelSEED::MS::DB::ComplexAlias->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfComplexAlias',
    as 'ArrayRef[ModelSEED::MS::DB::ComplexAlias]';
coerce 'ModelSEED::MS::ArrayRefOfComplexAlias',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::ComplexAlias->new( $_ ) } @{$_} ] };

1;
