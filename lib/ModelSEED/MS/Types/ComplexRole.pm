#
# Subtypes for ModelSEED::MS::ComplexRole
#
package ModelSEED::MS::Types::ComplexRole;
use Moose::Util::TypeConstraints;
use Class::Autouse qw ( ModelSEED::MS::DB::ComplexRole );

coerce 'ModelSEED::MS::ComplexRole',
    from 'HashRef',
    via { ModelSEED::MS::DB::ComplexRole->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfComplexRole',
    as 'ArrayRef[ModelSEED::MS::DB::ComplexRole]';
coerce 'ModelSEED::MS::ArrayRefOfComplexRole',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::ComplexRole->new( $_ ) } @{$_} ] };

1;
