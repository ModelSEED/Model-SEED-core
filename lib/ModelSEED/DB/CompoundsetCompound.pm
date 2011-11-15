package ModelSEED::DB::CompoundsetCompound;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'compoundset_compound',

    columns => [
        compoundset => { type => 'character', length => 36, not_null => 1 },
        compound    => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'compoundset', 'compound' ],

    foreign_keys => [
        compound_obj => {
            class       => 'ModelSEED::DB::Compound',
            key_columns => { compound => 'uuid' },
        },

        compoundset_obj => {
            class       => 'ModelSEED::DB::Compoundset',
            key_columns => { compoundset => 'uuid' },
        },
    ],
);

1;

