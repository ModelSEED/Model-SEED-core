#
# Subtypes for ModelSEED::MS::Biomass
#
package ModelSEED::MS::Types::Biomass;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Biomass;

coerce 'ModelSEED::MS::Biomass',
    from 'HashRef',
    via { ModelSEED::MS::DB::Biomass->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfBiomass',
    as 'ArrayRef[ModelSEED::MS::Biomass]';
coerce 'ModelSEED::MS::ArrayRefOfBiomass',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::Biomass->new( $_ ) } @{$_} ] };

1;
