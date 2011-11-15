package ModelSEED::DB::BiochemistryReaction;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'biochemistry_reaction',

    columns => [
        biochemistry => { type => 'character', length => 36, not_null => 1 },
        reaction     => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'biochemistry', 'reaction' ],

    foreign_keys => [
        biochemistry_obj => {
            class       => 'ModelSEED::DB::Biochemistry',
            key_columns => { biochemistry => 'uuid' },
        },

        reaction_obj => {
            class       => 'ModelSEED::DB::Reaction',
            key_columns => { reaction => 'uuid' },
        },
    ],
);

1;

