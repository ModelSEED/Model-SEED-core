package ModelSEED::DB::Biochemistry;


use strict;
use Data::UUID;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'biochemistries',

    columns => [
        uuid    => { type => 'character', length => 36, not_null => 1 },
        modDate => { type => 'datetime' },
        locked  => { type => 'integer' },
        public  => { type => 'integer' },
        name    => { type => 'varchar', length => 255 },
    ],

    primary_key_columns => [ 'uuid' ],

    relationships => [
        biochemistry_aliases => {
            class      => 'ModelSEED::DB::BiochemistryAlias',
            column_map => { uuid => 'biochemistry_uuid' },
            type       => 'one to many',
        },

        media => {
            map_class  => 'ModelSEED::DB::BiochemistryMedia',
            map_from   => 'biochemistry',
            map_to     => 'media',
            type       => 'many to many',
        },

        children => {
            map_class => 'ModelSEED::DB::BiochemistryParent',
            map_from  => 'parent',
            map_to    => 'child',
            type      => 'many to many',
        },

        compartments => {
            map_class => 'ModelSEED::DB::BiochemistryCompartment',
            map_from  => 'biochemistry',
            map_to    => 'compartment',
            type      => 'many to many',
        },

        compounds => {
            map_class => 'ModelSEED::DB::BiochemistryCompound',
            map_from  => 'biochemistry',
            map_to    => 'compound',
            type      => 'many to many',
        },

        compoundsets => {
            map_class => 'ModelSEED::DB::BiochemistryCompoundset',
            map_from  => 'biochemistry',
            map_to    => 'compoundset',
            type      => 'many to many',
        },

        mappings => {
            class      => 'ModelSEED::DB::Mapping',
            column_map => { uuid => 'biochemistry_uuid' },
            type       => 'one to many',
        },

        models => {
            class      => 'ModelSEED::DB::Model',
            column_map => { uuid => 'biochemistry_uuid' },
            type       => 'one to many',
        },

        parents => {
            map_class => 'ModelSEED::DB::BiochemistryParent',
            map_from  => 'child',
            map_to    => 'parent',
            type      => 'many to many',
        },

        reactions => {
            map_class => 'ModelSEED::DB::BiochemistryReaction',
            map_from  => 'biochemistry',
            map_to    => 'reaction',
            type      => 'many to many',
        },

        reactionsets => {
            map_class => 'ModelSEED::DB::BiochemistryReactionset',
            map_from  => 'biochemistry',
            map_to    => 'reactionset',
            type      => 'many to many',
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


1;
