package ModelSEED::DB::Reagent;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'reagents',

    columns => [
        reaction_uuid    => { type => 'character', length => 36, not_null => 1 },
        compound_uuid    => { type => 'character', length => 36, not_null => 1 },
        compartmentIndex => { type => 'integer', not_null => 1 },
        coefficient      => { type => 'scalar' },
        cofactor         => { type => 'integer' },
    ],

    primary_key_columns => [ 'reaction_uuid', 'compound_uuid', 'compartmentIndex' ],

    foreign_keys => [
        compound => {
            class       => 'ModelSEED::DB::Compound',
            key_columns => { compound_uuid => 'uuid' },
        },


        reaction => {
            class       => 'ModelSEED::DB::Reaction',
            key_columns => { reaction_uuid => 'uuid' },
        },
    ],

    relationships => [
        default_transported_reagent => {
            class      => 'ModelSEED::DB::DefaultTransportedReagent',
            column_map => { reaction_uuid => 'reaction_uuid',
                            compound_uuid => 'compound_uuid',
                            compartmentIndex => 'compartmentIndex',
                          },
            type       => 'one to one',
        },
    ],
        
);

1;
