package ModelSEED::DB::RolesetRole;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'roleset_role',

    columns => [
        roleset => { type => 'character', length => 36, not_null => 1 },
        role    => { type => 'character', length => 36, not_null => 1 },
        modDate => { type => 'datetime' },
    ],

    primary_key_columns => [ 'roleset', 'role' ],

    foreign_keys => [
        role_obj => {
            class       => 'ModelSEED::DB::Role',
            key_columns => { role => 'uuid' },
        },

        roleset_obj => {
            class       => 'ModelSEED::DB::Roleset',
            key_columns => { roleset => 'uuid' },
        },
    ],
);

1;

