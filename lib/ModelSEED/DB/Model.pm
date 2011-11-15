package ModelSEED::DB::Model;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'model',

    columns => [
        uuid         => { type => 'character', length => 36, not_null => 1 },
        modDate      => { type => 'datetime' },
        locked       => { type => 'integer' },
        public       => { type => 'integer' },
        id           => { type => 'varchar', length => 255 },
        name         => { type => 'varchar', length => 32 },
        version      => { type => 'integer' },
        type         => { type => 'varchar', length => 32 },
        status       => { type => 'varchar', length => 32 },
        reactions    => { type => 'integer' },
        compounds    => { type => 'integer' },
        annotations  => { type => 'integer' },
        growth       => { type => 'scalar', length => 64 },
        current      => { type => 'integer' },
        mapping      => { type => 'character', length => 36, not_null => 1 },
        biochemistry => { type => 'character', length => 36, not_null => 1 },
        annotation   => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'uuid' ],

    foreign_keys => [
        annotation_obj => {
            class       => 'ModelSEED::DB::Annotation',
            key_columns => { annotation => 'uuid' },
        },

        biochemistry_obj => {
            class       => 'ModelSEED::DB::Biochemistry',
            key_columns => { biochemistry => 'uuid' },
        },

        mapping_obj => {
            class       => 'ModelSEED::DB::Mapping',
            key_columns => { mapping => 'uuid' },
        },
    ],

    relationships => [
        model_compartment => {
            class      => 'ModelSEED::DB::ModelCompartment',
            column_map => { uuid => 'model' },
            type       => 'one to many',
        },

        model_reaction => {
            class      => 'ModelSEED::DB::ModelReaction',
            column_map => { uuid => 'model' },
            type       => 'one to many',
        },

        modelfba => {
            class      => 'ModelSEED::DB::Modelfba',
            column_map => { uuid => 'model' },
            type       => 'one to many',
        },
    ],
);

1;

