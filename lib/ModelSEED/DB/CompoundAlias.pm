package ModelSEED::DB::CompoundAlias;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'compound_aliases',

    columns => [
        compound_uuid => { type => 'character', length => 36, not_null => 1 },
        alias         => { type => 'varchar', length => 255, not_null => 1 },
        modDate       => { type => 'varchar', length => 45 },
        type          => { type => 'varchar', length => 32, not_null => 1 },
    ],

    foreign_keys => [
        compound => {
            class       => 'ModelSEED::DB::Compound',
            key_columns => { compound_uuid => 'uuid' },
        },
    ],
);

1;
