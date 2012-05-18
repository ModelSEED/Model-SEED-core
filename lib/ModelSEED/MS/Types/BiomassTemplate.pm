#
# Subtypes for ModelSEED::MS::BiomassTemplate
#
package ModelSEED::MS::Types::BiomassTemplate;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::BiomassTemplate;

coerce 'ModelSEED::MS::BiomassTemplate',
    from 'HashRef',
    via { ModelSEED::MS::DB::BiomassTemplate->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfBiomassTemplate',
    as 'ArrayRef[ModelSEED::MS::BiomassTemplate]';
coerce 'ModelSEED::MS::ArrayRefOfBiomassTemplate',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::BiomassTemplate->new( $_ ) } @{$_} ] };

1;
