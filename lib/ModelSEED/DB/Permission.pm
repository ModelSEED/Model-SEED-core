package ModelSEED::DB::Permission;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'permission',

    columns => [
        object => { type => 'character', length => 36, not_null => 1 },
        user   => { type => 'varchar', length => 255, not_null => 1 },
        read   => { type => 'integer' },
        write  => { type => 'integer' },
        admin  => { type => 'integer' },
    ],

    primary_key_columns => [ 'object', 'user' ],
);

1;

