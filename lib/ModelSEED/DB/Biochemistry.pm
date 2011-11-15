package ModelSEED::DB::Biochemistry;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'biochemistry',

    columns => [
        uuid    => { type => 'character', length => 36, not_null => 1 },
        modDate => { type => 'datetime' },
        locked  => { type => 'integer' },
        public  => { type => 'integer' },
        name    => { type => 'varchar', length => 255 },
    ],

    primary_key_columns => [ 'uuid' ],

    relationships => [
        biochemistry_compound => {
            class      => 'ModelSEED::DB::BiochemistryCompound',
            column_map => { uuid => 'biochemistry' },
            type       => 'one to many',
        },

        biochemistry_compoundset => {
            class      => 'ModelSEED::DB::BiochemistryCompoundset',
            column_map => { uuid => 'biochemistry' },
            type       => 'one to many',
        },

        biochemistry_media => {
            class      => 'ModelSEED::DB::BiochemistryMedia',
            column_map => { uuid => 'biochemistry' },
            type       => 'one to many',
        },

        biochemistry_reaction => {
            class      => 'ModelSEED::DB::BiochemistryReaction',
            column_map => { uuid => 'biochemistry' },
            type       => 'one to many',
        },

        biochemistry_reactionset => {
            class      => 'ModelSEED::DB::BiochemistryReactionset',
            column_map => { uuid => 'biochemistry' },
            type       => 'one to many',
        },

        compound_alias => {
            map_class => 'ModelSEED::DB::BiochemistryCompoundAlia',
            map_from  => 'biochemistry_obj',
            map_to    => 'compound_alia',
            type      => 'many to many',
        },

        model => {
            class      => 'ModelSEED::DB::Model',
            column_map => { uuid => 'biochemistry' },
            type       => 'one to many',
        },

        reaction_alias => {
            map_class => 'ModelSEED::DB::BiochemistryReactionAlia',
            map_from  => 'biochemistry_obj',
            map_to    => 'reaction_alias',
            type      => 'many to many',
        },
    ],
);

1;

