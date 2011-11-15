package ModelSEED::DB::ModelfbaReaction;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'modelfba_reaction',

    columns => [
        modelfba => { type => 'character', length => 36, not_null => 1 },
        reaction => { type => 'character', length => 36, not_null => 1 },
        min      => { type => 'scalar', length => 64 },
        max      => { type => 'scalar', length => 64 },
        class    => { type => 'character', length => 1 },
    ],

    primary_key_columns => [ 'modelfba', 'reaction' ],

    foreign_keys => [
        modelfba_obj => {
            class       => 'ModelSEED::DB::Modelfba',
            key_columns => { modelfba => 'uuid' },
        },

        reaction_obj => {
            class       => 'ModelSEED::DB::Reaction',
            key_columns => { reaction => 'uuid' },
        },
    ],
);

1;

