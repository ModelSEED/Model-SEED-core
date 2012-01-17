package ModelSEED::DB::RolesetRole;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'roleset_roles',

    columns => [
        roleset_uuid => { type => 'character', length => 36, not_null => 1 },
        role_uuid    => { type => 'character', length => 36, not_null => 1 },
        modDate      => { type => 'datetime' },
    ],

    primary_key_columns => [ 'roleset_uuid', 'role_uuid' ],

    foreign_keys => [
        role => {
            class       => 'ModelSEED::DB::Role',
            key_columns => { role_uuid => 'uuid' },
        },

        roleset => {
            class       => 'ModelSEED::DB::Roleset',
            key_columns => { roleset_uuid => 'uuid' },
        },
    ],
);

1;
