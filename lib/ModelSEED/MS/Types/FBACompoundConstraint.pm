#
# Subtypes for ModelSEED::MS::FBACompoundConstraint
#
package ModelSEED::MS::Types::FBACompoundConstraint;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FBACompoundConstraint;

coerce 'ModelSEED::MS::FBACompoundConstraint',
    from 'HashRef',
    via { ModelSEED::MS::DB::FBACompoundConstraint->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfFBACompoundConstraint',
    as 'ArrayRef[ModelSEED::MS::FBACompoundConstraint]';
coerce 'ModelSEED::MS::ArrayRefOfFBACompoundConstraint',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::FBACompoundConstraint->new( $_ ) } @{$_} ] };

1;
