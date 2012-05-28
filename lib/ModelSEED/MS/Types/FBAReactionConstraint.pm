#
# Subtypes for ModelSEED::MS::FBAReactionConstraint
#
package ModelSEED::MS::Types::FBAReactionConstraint;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FBAReactionConstraint;

coerce 'ModelSEED::MS::FBAReactionConstraint',
    from 'HashRef',
    via { ModelSEED::MS::DB::FBAReactionConstraint->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfFBAReactionConstraint',
    as 'ArrayRef[ModelSEED::MS::FBAReactionConstraint]';
coerce 'ModelSEED::MS::ArrayRefOfFBAReactionConstraint',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::FBAReactionConstraint->new( $_ ) } @{$_} ] };

1;
