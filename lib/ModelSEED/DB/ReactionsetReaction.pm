package ModelSEED::DB::ReactionsetReaction;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'reactionset_reaction',

    columns => [
        reactionset => { type => 'character', length => 36, not_null => 1 },
        reaction    => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'reactionset', 'reaction' ],

    foreign_keys => [
        reaction_obj => {
            class       => 'ModelSEED::DB::Reaction',
            key_columns => { reaction => 'uuid' },
        },

        reactionset_obj => {
            class       => 'ModelSEED::DB::Reactionset',
            key_columns => { reactionset => 'uuid' },
        },
    ],
);

1;

