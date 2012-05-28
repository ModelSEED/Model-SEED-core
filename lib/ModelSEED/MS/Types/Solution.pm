#
# Subtypes for ModelSEED::MS::Solution
#
package ModelSEED::MS::Types::Solution;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Solution;

coerce 'ModelSEED::MS::Solution',
    from 'HashRef',
    via { ModelSEED::MS::DB::Solution->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfSolution',
    as 'ArrayRef[ModelSEED::MS::Solution]';
coerce 'ModelSEED::MS::ArrayRefOfSolution',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::Solution->new( $_ ) } @{$_} ] };

1;
