package ModelSEED::DB::DefaultTransportedReagent;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'default_transported_reagents',

    columns => [
        reaction_uuid        => { type => 'character', length => 36, not_null => 1 },
        compound_uuid        => { type => 'character', length => 36, not_null => 1 },
        compartment_uuid     => { type => 'character', length => 36, not_null => 1 },
        compartmentIndex     => { type => 'integer', not_null => 1 },
        transportCoefficient => { type => 'integer', not_null => 1 },
        isImport             => { type => 'integer' },
    ],

    primary_key_columns => [ 'reaction_uuid', 'compartmentIndex' ],

    foreign_keys => [
        defaultCompartment => {
            class       => 'ModelSEED::DB::Compartment',
            key_columns => { compartment_uuid => 'uuid' },
        },

        compound => {
            class       => 'ModelSEED::DB::Compound',
            key_columns => { compound_uuid => 'uuid' },
        },

        reaction => {
            class       => 'ModelSEED::DB::Reaction',
            key_columns => { reaction_uuid => 'uuid' },
        },
    ],
);

1;

