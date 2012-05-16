#
# Subtypes for ModelSEED::MS::ConstraintVariable
#
package ModelSEED::MS::Types::ConstraintVariable;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::ConstraintVariable;

coerce 'ModelSEED::MS::DB::ConstraintVariable',
    from 'HashRef',
    via { ModelSEED::MS::DB::ConstraintVariable->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfConstraintVariable',
    as 'ArrayRef[ModelSEED::MS::DB::ConstraintVariable]';
coerce 'ModelSEED::MS::ArrayRefOfConstraintVariable',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::ConstraintVariable->new( $_ ) } @{$_} ] };

1;
