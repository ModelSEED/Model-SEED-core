package ModelSEED::DB::BiochemistryCompoundAlias;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'biochemistry_compound_alias',

    columns => [
        biochemistry => { type => 'character', length => 36, not_null => 1 },
        compound     => { type => 'character', length => 36, not_null => 1 },
        alias        => { type => 'varchar', length => 255, not_null => 1 },
    ],

    primary_key_columns => [ 'biochemistry', 'compound', 'alias' ],

    foreign_keys => [
        biochemistry_obj => {
            class       => 'ModelSEED::DB::Biochemistry',
            key_columns => { biochemistry => 'uuid' },
        },

        compound_alias => {
            class       => 'ModelSEED::DB::CompoundAlias',
            key_columns => {
                alias    => 'alias',
                compound => 'compound',
            },
        },
    ],
);

1;

