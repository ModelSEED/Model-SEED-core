#
# Subtypes for ModelSEED::MS::FBACompoundConstraint
#
package ModelSEED::MS::Types::FBACompoundConstraint;
use Moose::Util::TypeConstraints;
use Class::Autouse qw ( ModelSEED::MS::DB::FBACompoundConstraint );

coerce 'ModelSEED::MS::FBACompoundConstraint',
    from 'HashRef',
    via { ModelSEED::MS::DB::FBACompoundConstraint->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfFBACompoundConstraint',
    as 'ArrayRef[ModelSEED::MS::DB::FBACompoundConstraint]';
coerce 'ModelSEED::MS::ArrayRefOfFBACompoundConstraint',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::FBACompoundConstraint->new( $_ ) } @{$_} ] };

1;
