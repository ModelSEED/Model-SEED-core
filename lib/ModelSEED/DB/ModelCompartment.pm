package ModelSEED::DB::ModelCompartment;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'model_compartment',

    columns => [
        model       => { type => 'character', length => 36, not_null => 1 },
        compartment => { type => 'character', length => 36, not_null => 1 },
        index       => { type => 'integer' },
        label       => { type => 'varchar', length => 255 },
        pH          => { type => 'scalar', length => 64 },
        potential   => { type => 'scalar', length => 64 },
    ],

    primary_key_columns => [ 'model', 'compartment' ],

    foreign_keys => [
        compartment_obj => {
            class       => 'ModelSEED::DB::Compartment',
            key_columns => { compartment => 'uuid' },
        },

        model_obj => {
            class       => 'ModelSEED::DB::Model',
            key_columns => { model => 'uuid' },
        },
    ],
);

1;

