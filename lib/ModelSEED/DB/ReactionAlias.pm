package ModelSEED::DB::ReactionAlias;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'reaction_aliases',

    columns => [
        reaction_uuid => { type => 'character', length => 36, not_null => 1 },
        alias         => { type => 'varchar', length => 255, not_null => 1 },
        type          => { type => 'varchar', length => 32, not_null => 1 },
    ],

    foreign_keys => [
        reaction => {
            class       => 'ModelSEED::DB::Reaction',
            key_columns => { reaction_uuid => 'uuid' },
        },
    ],
);

1;
