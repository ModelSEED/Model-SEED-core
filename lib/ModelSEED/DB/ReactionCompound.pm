package ModelSEED::DB::ReactionCompound;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'reaction_compound',

    columns => [
        reaction    => { type => 'character', length => 36, not_null => 1 },
        compound    => { type => 'character', length => 36, not_null => 1 },
        coefficient => { type => 'scalar', length => 64 },
        cofactor    => { type => 'integer' },
        exteriorCompartment => { type => 'integer' }
   ],

    primary_key_columns => [ 'reaction', 'compound', 'exteriorCompartment' ],

    foreign_keys => [
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

