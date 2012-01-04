package ModelSEED::DB::Genome;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'genomes',

    columns => [
        uuid         => { type => 'character', length => 36, not_null => 1 },
        modDate      => { type => 'datetime' },
        locked       => { type => 'integer' },
        public       => { type => 'integer' },
        id           => { type => 'varchar', length => 32 },
        name         => { type => 'varchar', length => 32 },
        source       => { type => 'varchar', length => 32 },
        type         => { type => 'varchar', length => 32 },
        taxonomy     => { type => 'varchar', length => 255 },
        cksum        => { type => 'varchar', length => 255 },
        size         => { type => 'integer' },
        genes        => { type => 'integer' },
        gc           => { type => 'scalar' },
        gramPositive => { type => 'character', length => 1 },
        aerobic      => { type => 'character', length => 1 },
    ],

    primary_key_columns => [ 'uuid' ],

    relationships => [
        annotations => {
            class      => 'ModelSEED::DB::Annotation',
            column_map => { uuid => 'genome_uuid' },
            type       => 'one to many',
        },

        features => {
            class      => 'ModelSEED::DB::Feature',
            column_map => { uuid => 'genome_uuid' },
            type       => 'one to many',
        },
    ],
);

1;

