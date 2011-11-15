package ModelSEED::DB::ReactionCompound;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'reaction_compound',

    columns => [
        reaction    => { type => 'character', length => 36, not_null => 1 },
        compound    => { type => 'character', length => 36, not_null => 1 },
        compartment => { type => 'character', length => 36, not_null => 1 },
        coefficient => { type => 'scalar', length => 64 },
        cofactor    => { type => 'integer' },
    ],

    primary_key_columns => [ 'reaction', 'compound', 'compartment' ],

    foreign_keys => [
        compartment_obj => {
            class       => 'ModelSEED::DB::Compartment',
            key_columns => { compartment => 'uuid' },
        },

        compound_obj => {
            class       => 'ModelSEED::DB::Compound',
            key_columns => { compound => 'uuid' },
        },

        reaction_obj => {
            class       => 'ModelSEED::DB::Reaction',
            key_columns => { reaction => 'uuid' },
        },
    ],
);

1;

