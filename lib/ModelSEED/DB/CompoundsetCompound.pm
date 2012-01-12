package ModelSEED::DB::CompoundsetCompound;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'compoundset_compounds',

    columns => [
        compoundset_uuid => { type => 'character', length => 36, not_null => 1 },
        compound_uuid    => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'compoundset_uuid', 'compound_uuid' ],

    foreign_keys => [
        compound => {
            class       => 'ModelSEED::DB::Compound',
            key_columns => { compound_uuid => 'uuid' },
        },

        compoundset => {
            class       => 'ModelSEED::DB::Compoundset',
            key_columns => { compoundset_uuid => 'uuid' },
        },
    ],
);

1;
