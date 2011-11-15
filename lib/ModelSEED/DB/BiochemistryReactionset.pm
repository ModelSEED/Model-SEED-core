package ModelSEED::DB::BiochemistryReactionset;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'biochemistry_reactionset',

    columns => [
        biochemistry => { type => 'character', length => 36, not_null => 1 },
        reactionset  => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'biochemistry', 'reactionset' ],

    foreign_keys => [
        biochemistry_obj => {
            class       => 'ModelSEED::DB::Biochemistry',
            key_columns => { biochemistry => 'uuid' },
        },

        reactionset_obj => {
            class       => 'ModelSEED::DB::Reactionset',
            key_columns => { reactionset => 'uuid' },
        },
    ],
);

1;

