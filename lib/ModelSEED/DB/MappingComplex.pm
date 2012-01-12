package ModelSEED::DB::MappingComplex;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'mapping_complexes',

    columns => [
        mapping_uuid => { type => 'character', length => 36, not_null => 1 },
        complex_uuid => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'mapping_uuid', 'complex_uuid' ],

    foreign_keys => [
        complex => {
            class       => 'ModelSEED::DB::Complex',
            key_columns => { complex_uuid => 'uuid' },
        },

        mapping => {
            class       => 'ModelSEED::DB::Mapping',
            key_columns => { mapping_uuid => 'uuid' },
        },
    ],
);

1;
