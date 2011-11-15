package ModelSEED::DB::BiochemistryReactionAlia;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'biochemistry_reaction_alias',

    columns => [
        biochemistry => { type => 'character', length => 36, not_null => 1 },
        reaction     => { type => 'character', length => 36, not_null => 1 },
        alias        => { type => 'varchar', length => 255, not_null => 1 },
    ],

    primary_key_columns => [ 'biochemistry', 'reaction', 'alias' ],

    foreign_keys => [
        biochemistry_obj => {
            class       => 'ModelSEED::DB::Biochemistry',
            key_columns => { biochemistry => 'uuid' },
        },

        reaction_alia => {
            class       => 'ModelSEED::DB::ReactionAlia',
            key_columns => {
                alias    => 'alias',
                reaction => 'reaction',
            },
        },
    ],
);

1;

