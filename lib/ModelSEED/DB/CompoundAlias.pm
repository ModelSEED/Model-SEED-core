package ModelSEED::DB::CompoundAlias;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'compound_alias',

    columns => [
        compound => { type => 'character', length => 36, not_null => 1 },
        alias    => { type => 'varchar', length => 255, not_null => 1 },
        modDate  => { type => 'varchar', length => 45 },
        type     => { type => 'varchar', length => 32, not_null => 1 },
    ],

    primary_key_columns => [ 'compound', 'alias' ],

    foreign_keys => [
        compound_obj => {
            class       => 'ModelSEED::DB::Compound',
            key_columns => { compound => 'uuid' },
        },
    ],

    relationships => [
        biochemistry_objs => {
            map_class => 'ModelSEED::DB::BiochemistryCompoundAlias',
            map_from  => 'compound_alia',
            map_to    => 'biochemistry_obj',
            type      => 'many to many',
        },
    ],
);

1;

