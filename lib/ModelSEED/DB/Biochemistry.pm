package ModelSEED::DB::Biochemistry;

use strict;
use Data::UUID;
use DateTime;

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
        compound => {
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
            map_to     => 'media_obj',
            type       => 'many to many',
        },
        reaction => {
            map_class  => 'ModelSEED::DB::BiochemistryReaction',
            map_from   => 'biochemistry_obj',
            map_to     => 'reaction_obj',
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
            map_class => 'ModelSEED::DB::BiochemistryReactionAlias',
            map_from  => 'biochemistry_obj',
            map_to    => 'reaction_alias',
            type      => 'many to many',
        },
        parents => {
            map_class => 'ModelSEED::DB::BiochemistryParents',
            map_from  => 'child_obj',
            map_to    => 'parent_obj',
            type      => 'many to many',
        }, 
        children => {
            map_class => 'ModelSEED::DB::BiochemistryParents',
            map_from  => 'parent_obj',
            map_to    => 'child_obj',
            type      => 'many to many',
        },
        alias => {
            class      => 'ModelSEED::DB::BiochemistryAlias',
            column_map => { uuid => 'biochemistry' },
            type       => 'one to many',
        },
    ],
);

__PACKAGE__->meta->column('uuid')->add_trigger(
    deflate => sub {
        my $uuid = $_[0]->uuid;
        if(ref($uuid) && ref($uuid) eq 'Data::UUID') {
            return $uuid->to_string();
        } elsif($uuid) {
            return $uuid;
        } else {
            return Data::UUID->new()->create_str();
        }   
});

__PACKAGE__->meta->column('modDate')->add_trigger(
    deflate => sub {
        unless(defined($_[0]->modDate)) {
            return DateTime->now();
        }
});

1;

