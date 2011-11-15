package ModelSEED::DB::ReactionComplex;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'reaction_complex',

    columns => [
        reaction    => { type => 'character', length => 36, not_null => 1 },
        complex     => { type => 'character', length => 36, not_null => 1 },
        in          => { type => 'character', length => 36, not_null => 1 },
        out         => { type => 'character', length => 36, not_null => 1 },
        direction   => { type => 'character', length => 1 },
        transproton => { type => 'scalar', length => 64 },
    ],

    primary_key_columns => [ 'reaction', 'complex' ],

    foreign_keys => [
        compartment => {
            class       => 'ModelSEED::DB::Compartment',
            key_columns => { in => 'uuid' },
        },

        compartment_obj => {
            class       => 'ModelSEED::DB::Compartment',
            key_columns => { out => 'uuid' },
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

