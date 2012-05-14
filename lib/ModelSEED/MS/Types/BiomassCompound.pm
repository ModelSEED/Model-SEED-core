#
# Subtypes for ModelSEED::MS::BiomassCompound
#
package ModelSEED::MS::Types::BiomassCompound;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::BiomassCompound;

coerce 'ModelSEED::MS::DB::BiomassCompound',
    from 'HashRef',
    via { ModelSEED::MS::DB::BiomassCompound->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfBiomassCompound',
    as 'ArrayRef[ModelSEED::MS::DB::BiomassCompound]';
coerce 'ModelSEED::MS::ArrayRefOfBiomassCompound',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::BiomassCompound->new( $_ ) } @{$_} ] };

1;
