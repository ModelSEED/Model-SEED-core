#
# Subtypes for ModelSEED::MS::FBAFormulation
#
package ModelSEED::MS::Types::FBAFormulation;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FBAFormulation;

coerce 'ModelSEED::MS::FBAFormulation',
    from 'HashRef',
    via { ModelSEED::MS::DB::FBAFormulation->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfFBAFormulation',
    as 'ArrayRef[ModelSEED::MS::FBAFormulation]';
coerce 'ModelSEED::MS::ArrayRefOfFBAFormulation',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::FBAFormulation->new( $_ ) } @{$_} ] };

1;
