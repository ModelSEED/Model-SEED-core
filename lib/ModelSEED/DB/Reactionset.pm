package ModelSEED::DB::Reactionset;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'reactionset',

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
        biochemistry_reactionset => {
            class      => 'ModelSEED::DB::BiochemistryReactionset',
            column_map => { uuid => 'reactionset' },
            type       => 'one to many',
        },

        reactionset_reaction => {
            class      => 'ModelSEED::DB::ReactionsetReaction',
            column_map => { uuid => 'reactionset' },
            type       => 'one to many',
        },
    ],
);

1;

