#
# Subtypes for ModelSEED::MS::Constraint
#
package ModelSEED::MS::Types::Constraint;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::Constraint;

coerce 'ModelSEED::MS::DB::Constraint',
    from 'HashRef',
    via { ModelSEED::MS::DB::Constraint->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfConstraint',
    as 'ArrayRef[ModelSEED::MS::DB::Constraint]';
coerce 'ModelSEED::MS::ArrayRefOfConstraint',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::Constraint->new( $_ ) } @{$_} ] };

1;
