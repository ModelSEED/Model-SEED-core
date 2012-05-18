#
# Subtypes for ModelSEED::MS::Compartment
#
package ModelSEED::MS::Types::Compartment;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Compartment;

coerce 'ModelSEED::MS::Compartment',
    from 'HashRef',
    via { ModelSEED::MS::DB::Compartment->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfCompartment',
    as 'ArrayRef[ModelSEED::MS::Compartment]';
coerce 'ModelSEED::MS::ArrayRefOfCompartment',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::Compartment->new( $_ ) } @{$_} ] };

1;
