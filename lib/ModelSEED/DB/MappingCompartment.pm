package ModelSEED::DB::MappingCompartment;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'mapping_compartments',

    columns => [
        mapping_uuid     => { type => 'character', length => 36, not_null => 1 },
        compartment_uuid => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'mapping_uuid', 'compartment_uuid' ],

    foreign_keys => [
        compartment => {
            class       => 'ModelSEED::DB::Compartment',
            key_columns => { compartment_uuid => 'uuid' },
        },

        mapping => {
            class       => 'ModelSEED::DB::Mapping',
            key_columns => { mapping_uuid => 'uuid' },
        },
    ],
);

1;

