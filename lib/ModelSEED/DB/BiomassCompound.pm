package ModelSEED::DB::BiomassCompound;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'biomass_compounds',

    columns => [
        biomass_uuid           => { type => 'character', length => 36, not_null => 1 },
        compound_uuid          => { type => 'character', length => 36, not_null => 1 },
        modelcompartment_uuid => { type => 'character', length => 36, not_null => 1 },
        coefficient            => { type => 'scalar' },
    ],

    primary_key_columns => [ 'biomass_uuid', 'compound_uuid', 'modelcompartment_uuid' ],

    foreign_keys => [
        biomass => {
            class       => 'ModelSEED::DB::Biomass',
            key_columns => { biomass_uuid => 'uuid' },
        },

        model_compartment => {
            class       => 'ModelSEED::DB::ModelCompartment',
            key_columns => { modelcompartment_uuid => 'uuid' },
        },

        compound => {
            class       => 'ModelSEED::DB::Compound',
            key_columns => { compound_uuid => 'uuid' },
        },
    ],
);

1;
