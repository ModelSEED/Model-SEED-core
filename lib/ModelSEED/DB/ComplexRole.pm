package ModelSEED::DB::ComplexRole;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'complex_role',

    columns => [
        complex  => { type => 'character', length => 36, not_null => 1 },
        role     => { type => 'character', length => 36, not_null => 1 },
        optional => { type => 'integer' },
        type     => { type => 'character', length => 1 },
    ],

    primary_key_columns => [ 'complex', 'role' ],

    foreign_keys => [
        complex_obj => {
            class       => 'ModelSEED::DB::Complex',
            key_columns => { complex => 'uuid' },
        },

        role_obj => {
            class       => 'ModelSEED::DB::Role',
            key_columns => { role => 'uuid' },
        },
    ],
);

1;

