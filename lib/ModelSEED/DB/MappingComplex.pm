package ModelSEED::DB::MappingComplex;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'mapping_complex',

    columns => [
        mapping => { type => 'character', length => 36, not_null => 1 },
        complex => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'mapping', 'complex' ],

    foreign_keys => [
        complex_obj => {
            class       => 'ModelSEED::DB::Complex',
            key_columns => { complex => 'uuid' },
        },

        mapping_obj => {
            class       => 'ModelSEED::DB::Mapping',
            key_columns => { mapping => 'uuid' },
        },
    ],
);

1;

