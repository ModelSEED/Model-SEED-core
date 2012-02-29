package ModelSEED::DB::MappingRoleset;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'mapping_rolesets',

    columns => [
        mapping_uuid => { type => 'character', length => 36, not_null => 1 },
        roleset_uuid    => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'mapping_uuid', 'roleset_uuid' ],

    foreign_keys => [
        mapping => {
            class       => 'ModelSEED::DB::Mapping',
            key_columns => { mapping_uuid => 'uuid' },
        },

        roleset => {
            class       => 'ModelSEED::DB::roleset',
            key_columns => { roleset_uuid => 'uuid' },
        },
    ],
);

1;
