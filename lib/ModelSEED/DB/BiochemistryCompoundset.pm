package ModelSEED::DB::BiochemistryCompoundset;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'biochemistry_compoundset',

    columns => [
        biochemistry => { type => 'character', length => 36, not_null => 1 },
        compoundset  => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'biochemistry', 'compoundset' ],

    foreign_keys => [
        biochemistry_obj => {
            class       => 'ModelSEED::DB::Biochemistry',
            key_columns => { biochemistry => 'uuid' },
        },

        compoundset_obj => {
            class       => 'ModelSEED::DB::Compoundset',
            key_columns => { compoundset => 'uuid' },
        },
    ],
);

1;

