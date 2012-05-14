#
# Subtypes for ModelSEED::MS::BiomassCompound
#
package ModelSEED::MS::Types::BiomassCompound;
use Moose::Util::TypeConstraints;
use Class::Autouse qw ( ModelSEED::MS::DB::BiomassCompound );

coerce 'ModelSEED::MS::BiomassCompound',
    from 'HashRef',
    via { ModelSEED::MS::DB::BiomassCompound->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfBiomassCompound',
    as 'ArrayRef[ModelSEED::MS::DB::BiomassCompound]';
coerce 'ModelSEED::MS::ArrayRefOfBiomassCompound',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::BiomassCompound->new( $_ ) } @{$_} ] };

1;
