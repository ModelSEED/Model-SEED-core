#
# Subtypes for ModelSEED::MS::ConstraintVariable
#
package ModelSEED::MS::Types::ConstraintVariable;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ConstraintVariable;

coerce 'ModelSEED::MS::ConstraintVariable',
    from 'HashRef',
    via { ModelSEED::MS::DB::ConstraintVariable->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfConstraintVariable',
    as 'ArrayRef[ModelSEED::MS::ConstraintVariable]';
coerce 'ModelSEED::MS::ArrayRefOfConstraintVariable',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::ConstraintVariable->new( $_ ) } @{$_} ] };

1;
