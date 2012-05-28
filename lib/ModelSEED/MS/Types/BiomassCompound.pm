#
# Subtypes for ModelSEED::MS::BiomassCompound
#
package ModelSEED::MS::Types::BiomassCompound;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::BiomassCompound;

coerce 'ModelSEED::MS::BiomassCompound',
    from 'HashRef',
    via { ModelSEED::MS::DB::BiomassCompound->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfBiomassCompound',
    as 'ArrayRef[ModelSEED::MS::BiomassCompound]';
coerce 'ModelSEED::MS::ArrayRefOfBiomassCompound',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::BiomassCompound->new( $_ ) } @{$_} ] };

1;
