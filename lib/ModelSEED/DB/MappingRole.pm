package ModelSEED::DB::MappingRole;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'mapping_roles',

    columns => [
        mapping_uuid => { type => 'character', length => 36, not_null => 1 },
        role_uuid    => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'mapping_uuid', 'role_uuid' ],

    foreign_keys => [
        mapping => {
            class       => 'ModelSEED::DB::Mapping',
            key_columns => { mapping_uuid => 'uuid' },
        },

        role => {
            class       => 'ModelSEED::DB::Role',
            key_columns => { role_uuid => 'uuid' },
        },
    ],
);

1;
