package ModelSEED::DB::Compoundset;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'compoundset',

    columns => [
        uuid       => { type => 'character', length => 36, not_null => 1 },
        modDate    => { type => 'datetime' },
        id         => { type => 'varchar', length => 32 },
        name       => { type => 'varchar', length => 255 },
        searchname => { type => 'varchar', length => 255 },
        class      => { type => 'varchar', length => 255 },
        type       => { type => 'varchar', length => 32 },
    ],

    primary_key_columns => [ 'uuid' ],

    relationships => [
        biochemistry_compoundset => {
            class      => 'ModelSEED::DB::BiochemistryCompoundset',
            column_map => { uuid => 'compoundset' },
            type       => 'one to many',
        },

        compoundset_compound => {
            class      => 'ModelSEED::DB::CompoundsetCompound',
            column_map => { uuid => 'compoundset' },
            type       => 'one to many',
        },
    ],
);

1;

