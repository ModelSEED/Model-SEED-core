package ModelSEED::DB::ModelfbaCompound;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'modelfba_compound',

    columns => [
        modelfba => { type => 'character', length => 36, not_null => 1 },
        compound => { type => 'character', length => 36, not_null => 1 },
        min      => { type => 'scalar', length => 64 },
        max      => { type => 'scalar', length => 64 },
        class    => { type => 'character', length => 1 },
    ],

    primary_key_columns => [ 'modelfba', 'compound' ],

    foreign_keys => [
        compound_obj => {
            class       => 'ModelSEED::DB::Compound',
            key_columns => { compound => 'uuid' },
        },

        modelfba_obj => {
            class       => 'ModelSEED::DB::Modelfba',
            key_columns => { modelfba => 'uuid' },
        },
    ],
);

1;

