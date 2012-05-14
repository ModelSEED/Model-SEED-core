#
# Subtypes for ModelSEED::MS::FluxMeasurement
#
package ModelSEED::MS::Types::FluxMeasurement;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::FluxMeasurement;

coerce 'ModelSEED::MS::DB::FluxMeasurement',
    from 'HashRef',
    via { ModelSEED::MS::DB::FluxMeasurement->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfFluxMeasurement',
    as 'ArrayRef[ModelSEED::MS::DB::FluxMeasurement]';
coerce 'ModelSEED::MS::ArrayRefOfFluxMeasurement',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::FluxMeasurement->new( $_ ) } @{$_} ] };

1;
