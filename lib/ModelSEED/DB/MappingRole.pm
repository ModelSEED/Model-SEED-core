package ModelSEED::DB::MappingRole;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'mapping_role',

    columns => [
        mapping => { type => 'character', length => 36, not_null => 1 },
        role    => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'mapping', 'role' ],

    foreign_keys => [
        mapping_obj => {
            class       => 'ModelSEED::DB::Mapping',
            key_columns => { mapping => 'uuid' },
        },

        role_obj => {
            class       => 'ModelSEED::DB::Role',
            key_columns => { role => 'uuid' },
        },
    ],
);

1;

