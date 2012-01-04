package ModelSEED::DB::Modelfba;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'modelfbas',

    columns => [
        uuid       => { type => 'character', length => 36, not_null => 1 },
        modDate    => { type => 'varchar', length => 45 },
        locked     => { type => 'integer' },
        model_uuid => { type => 'character', length => 36, not_null => 1 },
        media_uuid => { type => 'character', length => 36, not_null => 1 },
        options    => { type => 'varchar', length => 255 },
        geneko     => { type => 'varchar', length => 255 },
        reactionko => { type => 'varchar', length => 255 },
    ],

    primary_key_columns => [ 'uuid' ],

    foreign_keys => [
        media => {
            class       => 'ModelSEED::DB::Media',
            key_columns => { media_uuid => 'uuid' },
        },

        model => {
            class       => 'ModelSEED::DB::Model',
            key_columns => { model_uuid => 'uuid' },
        },
    ],

    relationships => [
        modelfba_compounds => {
            class => 'ModelSEED::DB::ModelfbaCompound',
            column_map => { uuid => 'modelfba_uuid' },
            type      => 'one to many',
        },

        modelfba_features => {
            map_class => 'ModelSEED::DB::ModelessFeature',
            column_map => { uuid => 'modelfba_uuid' },
            type      => 'one to many',
        },

        modelfba_reactions => {
            map_class => 'ModelSEED::DB::ModelfbaReaction',
            column_map => { uuid => 'modelfba_uuid' },
            type      => 'one to many',
        },
    ],
);

1;

