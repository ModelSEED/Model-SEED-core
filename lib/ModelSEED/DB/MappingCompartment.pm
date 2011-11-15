package ModelSEED::DB::MappingCompartment;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'mapping_compartment',

    columns => [
        mapping     => { type => 'character', length => 36, not_null => 1 },
        compartment => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'mapping', 'compartment' ],

    foreign_keys => [
        compartment_obj => {
            class       => 'ModelSEED::DB::Compartment',
            key_columns => { compartment => 'uuid' },
        },

        mapping_obj => {
            class       => 'ModelSEED::DB::Mapping',
            key_columns => { mapping => 'uuid' },
        },
    ],
);

1;

