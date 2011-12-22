package ModelSEED::DB::ReactionAlias;

use strict;
use DateTime;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'reaction_alias',

    columns => [
        reaction => { type => 'character', length => 36, not_null => 1 },
        alias    => { type => 'varchar', length => 255, not_null => 1 },
        modDate  => { type => 'varchar', length => 45 },
        type     => { type => 'varchar', length => 32, not_null => 1 },
    ],

    primary_key_columns => [ 'type', 'alias' ],

    foreign_keys => [
        reaction_obj => {
            class       => 'ModelSEED::DB::Reaction',
            key_columns => { reaction => 'uuid' },
        },
    ],

    relationships => [
        biochemistry_objs => {
            map_class => 'ModelSEED::DB::BiochemistryReactionAlias',
            map_from  => 'reaction_alias',
            map_to    => 'biochemistry_obj',
            type      => 'many to many',
        },
    ],
);

__PACKAGE__->meta->column('modDate')->add_trigger(
    deflate => sub {
        unless(defined($_[0]->modDate)) {
            return DateTime->now();
        }
});

1;

