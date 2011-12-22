package ModelSEED::DB::ModelAlias;
use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'model_alias',

    columns => [
        model => { type => 'character', length => 36, not_null => 1 },
        username     => { type => 'varchar', length => 255, not_null => 1 },
        id           => { type => 'varchar', length => 255, not_null => 1 },
    ],

    primary_key_columns => [ 'username', 'id' ],

    foreign_keys => [
        model_obj => {
            class       => 'ModelSEED::DB::Model',
            key_columns => { model => 'uuid' },
        },
    ],
);

1;

