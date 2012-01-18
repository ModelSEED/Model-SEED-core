package ModelSEED::DB::BiochemistryCompartment;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'biochemistry_compartments',

    columns => [
        biochemistry_uuid => { type => 'character', length => 36, not_null => 1 },
        compartment_uuid  => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'biochemistry_uuid', 'compartment_uuid' ],

    foreign_keys => [
        biochemistry => {
            class       => 'ModelSEED::DB::Biochemistry',
            key_columns => { biochemistry_uuid => 'uuid' },
        },

        compartment => {
            class       => 'ModelSEED::DB::Compartment',
            key_columns => { compartment_uuid => 'uuid' },
        },
    ],
);

1;

