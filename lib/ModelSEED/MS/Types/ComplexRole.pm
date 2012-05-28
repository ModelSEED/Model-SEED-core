#
# Subtypes for ModelSEED::MS::ComplexRole
#
package ModelSEED::MS::Types::ComplexRole;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ComplexRole;

coerce 'ModelSEED::MS::ComplexRole',
    from 'HashRef',
    via { ModelSEED::MS::DB::ComplexRole->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfComplexRole',
    as 'ArrayRef[ModelSEED::MS::ComplexRole]';
coerce 'ModelSEED::MS::ArrayRefOfComplexRole',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ComplexRole->new( $_ ) } @{$_} ] };

1;
