#
# Subtypes for ModelSEED::MS::MetaboliteMeasurement
#
package ModelSEED::MS::Types::MetaboliteMeasurement;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::MetaboliteMeasurement;

coerce 'ModelSEED::MS::MetaboliteMeasurement',
    from 'HashRef',
    via { ModelSEED::MS::DB::MetaboliteMeasurement->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfMetaboliteMeasurement',
    as 'ArrayRef[ModelSEED::MS::MetaboliteMeasurement]';
coerce 'ModelSEED::MS::ArrayRefOfMetaboliteMeasurement',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::MetaboliteMeasurement->new( $_ ) } @{$_} ] };

1;
