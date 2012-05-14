#
# Subtypes for ModelSEED::MS::Biomass
#
package ModelSEED::MS::Types::Biomass;
use Moose::Util::TypeConstraints;
use Class::Autouse qw ( ModelSEED::MS::DB::Biomass );

coerce 'ModelSEED::MS::Biomass',
    from 'HashRef',
    via { ModelSEED::MS::DB::Biomass->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfBiomass',
    as 'ArrayRef[ModelSEED::MS::DB::Biomass]';
coerce 'ModelSEED::MS::ArrayRefOfBiomass',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::Biomass->new( $_ ) } @{$_} ] };

1;
