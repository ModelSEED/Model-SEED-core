package ModelSEED::DB::Reactionset;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'reactionsets',

    columns => [
        uuid       => { type => 'character', length => 36, not_null => 1 },
        modDate    => { type => 'datetime' },
        locked     => { type => 'integer' },
        id         => { type => 'varchar', length => 32 },
        name       => { type => 'varchar', length => 255 },
        searchname => { type => 'varchar', length => 255 },
        class      => { type => 'varchar', length => 255 },
        type       => { type => 'varchar', length => 32 },
    ],

    primary_key_columns => [ 'uuid' ],

    relationships => [
        biochemistries => {
            map_class => 'ModelSEED::DB::BiochemistryReactionset',
            map_from  => 'reactionset',
            map_to    => 'biochemistry',
            type      => 'many to many',
        },

        reactions => {
            map_class => 'ModelSEED::DB::ReactionsetReaction',
            map_from  => 'reactionset',
            map_to    => 'reaction',
            type      => 'many to many',
        },
    ],
);

1;

