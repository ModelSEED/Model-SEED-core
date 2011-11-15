package ModelSEED::DB::Parent;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'parent',

    columns => [
        child  => { type => 'character', length => 36, not_null => 1 },
        parent => { type => 'character', length => 36, not_null => 1 },
        table  => { type => 'varchar', length => 30, not_null => 1 },
    ],

    primary_key_columns => [ 'child', 'parent' ],
);

1;

