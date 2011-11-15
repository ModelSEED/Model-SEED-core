package ModelSEED::DB::Complex;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'complex',

    columns => [
        uuid       => { type => 'character', length => 36, not_null => 1 },
        modDate    => { type => 'datetime' },
        id         => { type => 'varchar', length => 32 },
        name       => { type => 'varchar', length => 255 },
        searchname => { type => 'varchar', length => 255 },
    ],

    primary_key_columns => [ 'uuid' ],

    relationships => [
        complex_role => {
            class      => 'ModelSEED::DB::ComplexRole',
            column_map => { uuid => 'complex' },
            type       => 'one to many',
        },

        mapping_complex => {
            class      => 'ModelSEED::DB::MappingComplex',
            column_map => { uuid => 'complex' },
            type       => 'one to many',
        },

        reaction_complex => {
            class      => 'ModelSEED::DB::ReactionComplex',
            column_map => { uuid => 'complex' },
            type       => 'one to many',
        },
    ],
);

1;

