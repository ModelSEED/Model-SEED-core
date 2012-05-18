#
# Subtypes for ModelSEED::MS::SolutionVariable
#
package ModelSEED::MS::Types::SolutionVariable;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::SolutionVariable;

coerce 'ModelSEED::MS::SolutionVariable',
    from 'HashRef',
    via { ModelSEED::MS::DB::SolutionVariable->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfSolutionVariable',
    as 'ArrayRef[ModelSEED::MS::SolutionVariable]';
coerce 'ModelSEED::MS::ArrayRefOfSolutionVariable',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::SolutionVariable->new( $_ ) } @{$_} ] };

1;
