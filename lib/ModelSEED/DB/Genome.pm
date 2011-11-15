package ModelSEED::DB::Genome;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'genome',

    columns => [
        uuid       => { type => 'character', length => 36, not_null => 1 },
        modDate    => { type => 'datetime' },
        locked     => { type => 'integer' },
        public     => { type => 'integer' },
        id         => { type => 'varchar', length => 32 },
        name       => { type => 'varchar', length => 32 },
        source     => { type => 'varchar', length => 32 },
        type       => { type => 'varchar', length => 32 },
        taxonomy   => { type => 'varchar', length => 255 },
        md5        => { type => 'varchar', length => 255 },
        size       => { type => 'integer' },
        genes      => { type => 'integer' },
        gc         => { type => 'scalar', length => 64 },
        cellwall   => { type => 'character', length => 1 },
        aerobicity => { type => 'character', length => 1 },
        media      => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'uuid' ],

    foreign_keys => [
        media_obj => {
            class       => 'ModelSEED::DB::Media',
            key_columns => { media => 'uuid' },
        },
    ],

    relationships => [
        annotation => {
            class      => 'ModelSEED::DB::Annotation',
            column_map => { uuid => 'genome' },
            type       => 'one to many',
        },

        feature => {
            class      => 'ModelSEED::DB::Feature',
            column_map => { uuid => 'genome' },
            type       => 'one to many',
        },
    ],
);

1;

