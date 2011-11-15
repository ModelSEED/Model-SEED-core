package ModelSEED::DB::BiochemistryCompound;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'biochemistry_compound',

    columns => [
        biochemistry => { type => 'character', length => 36, not_null => 1 },
        compound     => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'biochemistry', 'compound' ],

    foreign_keys => [
        biochemistry_obj => {
            class       => 'ModelSEED::DB::Biochemistry',
            key_columns => { biochemistry => 'uuid' },
        },

        compound_obj => {
            class       => 'ModelSEED::DB::Compound',
            key_columns => { compound => 'uuid' },
        },
    ],
);

1;

