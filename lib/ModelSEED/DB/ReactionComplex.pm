package ModelSEED::DB::ReactionComplex;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
   table   => 'reaction_complex',

    columns => [
        reaction    => { type => 'character', length => 36, not_null => 1 },
        complex     => { type => 'character', length => 36, not_null => 1 },
        interiorCompartment => { type => 'character', length => 36, not_null => 1 },
        exteriorCompartment => { type => 'character', length => 36, not_null => 1 },
        direction   => { type => 'character', length => 1 },
        transprotonNature => { type => 'character', length => 255 },
    ],

    primary_key_columns => [ 'reaction', 'complex' ],

    foreign_keys => [
        interiorCompartment_obj => {
            class       => 'ModelSEED::DB::Compartment',
            key_columns => { interiorCompartment => 'uuid' },
        },

        exteriorCompartment_obj => {
            class       => 'ModelSEED::DB::Compartment',
            key_columns => { exteriorCompartment => 'uuid' },
        },

        complex_obj => {
            class       => 'ModelSEED::DB::Complex',
            key_columns => { complex => 'uuid' },
        },

        reaction_obj => {
            class       => 'ModelSEED::DB::Reaction',
            key_columns => { reaction => 'uuid' },
        },
    ],
);

1;

