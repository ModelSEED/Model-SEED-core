package ModelSEED::DB::Feature;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'feature',

    columns => [
        uuid    => { type => 'character', length => 36, not_null => 1 },
        modDate => { type => 'datetime' },
        id      => { type => 'varchar', length => 32 },
        md5     => { type => 'varchar', length => 255 },
        genome  => { type => 'character', length => 36, not_null => 1 },
        start   => { type => 'integer' },
        stop    => { type => 'integer' },
    ],

    primary_key_columns => [ 'uuid' ],

    foreign_keys => [
        genome_obj => {
            class       => 'ModelSEED::DB::Genome',
            key_columns => { genome => 'uuid' },
        },
    ],

    relationships => [
        annotation_feature => {
            class      => 'ModelSEED::DB::AnnotationFeature',
            column_map => { uuid => 'feature' },
            type       => 'one to many',
        },

        modeless_feature => {
            class      => 'ModelSEED::DB::ModelessFeature',
            column_map => { uuid => 'feature' },
            type       => 'one to many',
        },

        role => {
            class      => 'ModelSEED::DB::Role',
            column_map => { uuid => 'exemplar' },
            type       => 'one to many',
        },
    ],
);

1;

