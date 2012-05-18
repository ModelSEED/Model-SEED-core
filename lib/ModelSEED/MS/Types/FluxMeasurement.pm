#
# Subtypes for ModelSEED::MS::FluxMeasurement
#
package ModelSEED::MS::Types::FluxMeasurement;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FluxMeasurement;

coerce 'ModelSEED::MS::FluxMeasurement',
    from 'HashRef',
    via { ModelSEED::MS::DB::FluxMeasurement->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfFluxMeasurement',
    as 'ArrayRef[ModelSEED::MS::FluxMeasurement]';
coerce 'ModelSEED::MS::ArrayRefOfFluxMeasurement',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::FluxMeasurement->new( $_ ) } @{$_} ] };

1;
