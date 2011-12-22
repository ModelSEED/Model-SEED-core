package ModelSEED::DB::RolesetRole;

use strict;
use DateTime;

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

__PACKAGE__->meta->column('modDate')->add_trigger(
    deflate => sub {
        unless(defined($_[0]->modDate)) {
            return DateTime->now();
        }
});

1;

