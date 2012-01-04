package ModelSEED::DB::ReactionRule;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'reaction_rules',

    columns => [
        reaction_uuid     => { type => 'character', length => 36, not_null => 1 },
        complex_uuid      => { type => 'character', length => 36, not_null => 1 },
        compartment_uuid  => { type => 'character', length => 36, not_null => 1 },
        direction         => { type => 'character', length => 1 },
        transprotonNature => { type => 'character', length => 255 },
    ],

    primary_key_columns => [ 'reaction_uuid', 'complex_uuid' ],

    foreign_keys => [
        compartment => {
            class       => 'ModelSEED::DB::Compartment',
            key_columns => { compartment_uuid => 'uuid' },
        },

        complex => {
            class       => 'ModelSEED::DB::Complex',
            key_columns => { complex_uuid => 'uuid' },
        },

        reaction => {
            class       => 'ModelSEED::DB::Reaction',
            key_columns => { reaction_uuid => 'uuid' },
        },
    ],
);

1;

