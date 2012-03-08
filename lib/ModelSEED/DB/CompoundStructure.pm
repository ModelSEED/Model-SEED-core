package ModelSEED::DB::CompoundStructure;
use strict;
use DateTime;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'compound_structures',

    columns => [
        compound_uuid => { type => 'character', length => 36, not_null => 1 },
        structure     => { type => 'text', not_null => 1 },
        cksum         => { type => 'varchar', length => 255, not_null => 1 },
        type          => { type => 'varchar', length => 32, not_null => 1 },
    ],

    primary_key_columns => [ 'type', 'cksum', 'compound_uuid' ],

    foreign_keys => [
        compound => {
            class       => 'ModelSEED::DB::Compound',
            key_columns => { compound_uuid => 'uuid' },
        },
    ],
);

1;
