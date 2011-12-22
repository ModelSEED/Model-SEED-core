package ModelSEED::DB::MappingAlias;
use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'mapping_alias',

    columns => [
        mapping => { type => 'character', length => 36, not_null => 1 },
        username     => { type => 'varchar', length => 255, not_null => 1 },
        id           => { type => 'varchar', length => 255, not_null => 1 },
    ],

    primary_key_columns => [ 'username', 'id' ],

    foreign_keys => [
        mapping_obj => {
            class       => 'ModelSEED::DB::Mapping',
            key_columns => { mapping => 'uuid' },
        },
    ],
);

1;

