package ModelSEED::DB::ReactionRuleTransport;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'reaction_rule_transports',

    columns => [
        reaction_uuid    => { type => 'character', length => 36, not_null => 1 },
        complex_uuid     => { type => 'character', length => 36, not_null => 1 },
        compartmentIndex => { type => 'integer', not_null => 1 },
        compartment_uuid => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'reaction_uuid', 'complex_uuid', 'compartmentIndex' ],

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

