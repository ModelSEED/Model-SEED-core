#
# Subtypes for ModelSEED::MS::BiomassTemplateComponent
#
package ModelSEED::MS::Types::BiomassTemplateComponent;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::BiomassTemplateComponent;

coerce 'ModelSEED::MS::DB::BiomassTemplateComponent',
    from 'HashRef',
    via { ModelSEED::MS::DB::BiomassTemplateComponent->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfBiomassTemplateComponent',
    as 'ArrayRef[ModelSEED::MS::DB::BiomassTemplateComponent]';
coerce 'ModelSEED::MS::ArrayRefOfBiomassTemplateComponent',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::BiomassTemplateComponent->new( $_ ) } @{$_} ] };

1;
