#
# Subtypes for ModelSEED::MS::FBABiomassVariable
#
package ModelSEED::MS::Types::FBABiomassVariable;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FBABiomassVariable;

coerce 'ModelSEED::MS::FBABiomassVariable',
    from 'HashRef',
    via { ModelSEED::MS::DB::FBABiomassVariable->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfFBABiomassVariable',
    as 'ArrayRef[ModelSEED::MS::FBABiomassVariable]';
coerce 'ModelSEED::MS::ArrayRefOfFBABiomassVariable',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::FBABiomassVariable->new( $_ ) } @{$_} ] };

1;
