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
        compounds => {
            map_class  => 'ModelSEED::DB::BiochemistryCompound',
            map_from   => 'biochemistry_obj',
            map_to     => 'compound_obj',
            type       => 'many to many',
        },
        compoundSet => {
            map_class => 'ModelSEED::DB::BiochemistryCompoundset',
            map_from  => 'biochemistry_obj',
            map_to    => 'compoundset_obj',
            type      => 'many to many',
        },
        media => {
            map_class  => 'ModelSEED::DB::BiochemistryMedia',
            map_from   => 'biochemistry_obj',
            map_to     => 'compound_obj',
            type       => 'many to many',
        },
        reactions => {
            map_class  => 'ModelSEED::DB::BiochemistryReaction',
            map_from   => 'biochemistry_obj',
            map_to     => 'compound_obj',
            type       => 'many to many',
        },
        reactionSet => {
            map_class  => 'ModelSEED::DB::BiochemistryReactionset',
            map_from   => 'biochemistry_obj',
            map_to     => 'reactionset_obj',
            type       => 'many to many', 
        },
        
        compound_alias => {
            map_class => 'ModelSEED::DB::BiochemistryCompoundAlias',
            map_from  => 'biochemistry_obj',
            map_to    => 'compound_alias',
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

