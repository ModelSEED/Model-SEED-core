#
# Subtypes for ModelSEED::MS::SolutionConstraint
#
package ModelSEED::MS::Types::SolutionConstraint;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::SolutionConstraint;

coerce 'ModelSEED::MS::SolutionConstraint',
    from 'HashRef',
    via { ModelSEED::MS::DB::SolutionConstraint->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfSolutionConstraint',
    as 'ArrayRef[ModelSEED::MS::SolutionConstraint]';
coerce 'ModelSEED::MS::ArrayRefOfSolutionConstraint',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::SolutionConstraint->new( $_ ) } @{$_} ] };

1;
