#
# Subtypes for ModelSEED::MS::GeneMeasurement
#
package ModelSEED::MS::Types::GeneMeasurement;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::GeneMeasurement;

coerce 'ModelSEED::MS::DB::GeneMeasurement',
    from 'HashRef',
    via { ModelSEED::MS::DB::GeneMeasurement->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfGeneMeasurement',
    as 'ArrayRef[ModelSEED::MS::DB::GeneMeasurement]';
coerce 'ModelSEED::MS::ArrayRefOfGeneMeasurement',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::GeneMeasurement->new( $_ ) } @{$_} ] };

1;
