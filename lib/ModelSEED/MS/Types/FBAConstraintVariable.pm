#
# Subtypes for ModelSEED::MS::FBAConstraintVariable
#
package ModelSEED::MS::Types::FBAConstraintVariable;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FBAConstraintVariable;

coerce 'ModelSEED::MS::FBAConstraintVariable',
    from 'HashRef',
    via { ModelSEED::MS::DB::FBAConstraintVariable->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfFBAConstraintVariable',
    as 'ArrayRef[ModelSEED::MS::FBAConstraintVariable]';
coerce 'ModelSEED::MS::ArrayRefOfFBAConstraintVariable',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::FBAConstraintVariable->new( $_ ) } @{$_} ] };

1;
