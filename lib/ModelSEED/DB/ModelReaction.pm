package ModelSEED::DB::ModelReaction;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'model_reaction',

    columns => [
        model       => { type => 'character', length => 36, not_null => 1 },
        reaction    => { type => 'character', length => 36, not_null => 1 },
        direction   => { type => 'character', length => 1 },
        transproton => { type => 'scalar', length => 64 },
        protons     => { type => 'scalar', length => 64 },
        in          => { type => 'character', length => 36, not_null => 1 },
        out         => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'model', 'reaction' ],

    foreign_keys => [
        compartment => {
            class       => 'ModelSEED::DB::Compartment',
            key_columns => { in => 'uuid' },
        },

        compartment_obj => {
            class       => 'ModelSEED::DB::Compartment',
            key_columns => { out => 'uuid' },
        },

        model_obj => {
            class       => 'ModelSEED::DB::Model',
            key_columns => { model => 'uuid' },
        },

        reaction_obj => {
            class       => 'ModelSEED::DB::Reaction',
            key_columns => { reaction => 'uuid' },
        },
    ],
);

1;

