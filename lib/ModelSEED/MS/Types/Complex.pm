#
# Subtypes for ModelSEED::MS::Complex
#
package ModelSEED::MS::Types::Complex;
use Moose::Util::TypeConstraints;
use Class::Autouse qw ( ModelSEED::MS::DB::Complex );

coerce 'ModelSEED::MS::Complex',
    from 'HashRef',
    via { ModelSEED::MS::DB::Complex->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfComplex',
    as 'ArrayRef[ModelSEED::MS::DB::Complex]';
coerce 'ModelSEED::MS::ArrayRefOfComplex',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::Complex->new( $_ ) } @{$_} ] };

1;
