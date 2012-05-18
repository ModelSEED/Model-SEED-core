#
# Subtypes for ModelSEED::MS::UptakeMeasurement
#
package ModelSEED::MS::Types::UptakeMeasurement;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::UptakeMeasurement;

coerce 'ModelSEED::MS::UptakeMeasurement',
    from 'HashRef',
    via { ModelSEED::MS::DB::UptakeMeasurement->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfUptakeMeasurement',
    as 'ArrayRef[ModelSEED::MS::UptakeMeasurement]';
coerce 'ModelSEED::MS::ArrayRefOfUptakeMeasurement',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::UptakeMeasurement->new( $_ ) } @{$_} ] };

1;
