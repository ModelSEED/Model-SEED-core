#
# Subtypes for ModelSEED::MS::ModelCompartment
#
package ModelSEED::MS::Types::ModelCompartment;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::ModelCompartment;

coerce 'ModelSEED::MS::DB::ModelCompartment',
    from 'HashRef',
    via { ModelSEED::MS::DB::ModelCompartment->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfModelCompartment',
    as 'ArrayRef[ModelSEED::MS::DB::ModelCompartment]';
coerce 'ModelSEED::MS::ArrayRefOfModelCompartment',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::ModelCompartment->new( $_ ) } @{$_} ] };

1;
