#
# Subtypes for ModelSEED::MS::BiomassTemplate
#
package ModelSEED::MS::Types::BiomassTemplate;
use Moose::Util::TypeConstraints;
use Class::Autouse qw ( ModelSEED::MS::DB::BiomassTemplate );

coerce 'ModelSEED::MS::BiomassTemplate',
    from 'HashRef',
    via { ModelSEED::MS::DB::BiomassTemplate->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfBiomassTemplate',
    as 'ArrayRef[ModelSEED::MS::DB::BiomassTemplate]';
coerce 'ModelSEED::MS::ArrayRefOfBiomassTemplate',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::BiomassTemplate->new( $_ ) } @{$_} ] };

1;
