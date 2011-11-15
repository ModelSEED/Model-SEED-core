package ModelSEED::DB::Modelfba;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'modelfba',

    columns => [
        uuid       => { type => 'character', length => 36, not_null => 1 },
        modDate    => { type => 'varchar', length => 45 },
        model      => { type => 'character', length => 36, not_null => 1 },
        media      => { type => 'character', length => 36, not_null => 1 },
        options    => { type => 'varchar', length => 255 },
        geneko     => { type => 'varchar', length => 255 },
        reactionko => { type => 'varchar', length => 255 },
    ],

    primary_key_columns => [ 'uuid' ],

    foreign_keys => [
        media_obj => {
            class       => 'ModelSEED::DB::Media',
            key_columns => { media => 'uuid' },
        },

        model_obj => {
            class       => 'ModelSEED::DB::Model',
            key_columns => { model => 'uuid' },
        },
    ],

    relationships => [
        modeless_feature => {
            class      => 'ModelSEED::DB::ModelessFeature',
            column_map => { uuid => 'modelfba' },
            type       => 'one to many',
        },

        modelfba_compound => {
            class      => 'ModelSEED::DB::ModelfbaCompound',
            column_map => { uuid => 'modelfba' },
            type       => 'one to many',
        },

        modelfba_reaction => {
            class      => 'ModelSEED::DB::ModelfbaReaction',
            column_map => { uuid => 'modelfba' },
            type       => 'one to many',
        },
    ],
);

1;

