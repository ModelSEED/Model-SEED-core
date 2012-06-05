#
# Subtypes for ModelSEED::MS::FBAConstraint
#
package ModelSEED::MS::Types::FBAConstraint;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FBAConstraint;

coerce 'ModelSEED::MS::FBAConstraint',
    from 'HashRef',
    via { ModelSEED::MS::DB::FBAConstraint->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfFBAConstraint',
    as 'ArrayRef[ModelSEED::MS::FBAConstraint]';
coerce 'ModelSEED::MS::ArrayRefOfFBAConstraint',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::FBAConstraint->new( $_ ) } @{$_} ] };

1;
