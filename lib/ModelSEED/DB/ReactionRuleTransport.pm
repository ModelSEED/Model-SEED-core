package ModelSEED::DB::ReactionRuleTransport;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'reaction_rule_transports',

    columns => [
        reaction_rule_uuid   => { type => 'character', length => 36, not_null => 1 },
        compartmentIndex     => { type => 'integer', not_null => 1 },
        compartment_uuid     => { type => 'character', length => 36, not_null => 1 },
        compound_uuid     => { type => 'character', length => 36, not_null => 1 },
        reaction_uuid     => { type => 'character', length => 36, not_null => 1 },
        transportCoefficient => { type => 'integer', not_null => 1 },
        isImport             => { type => 'integer' },
    ],

    primary_key_columns => [ 'reaction_rule_uuid', 'compartmentIndex' ],

    foreign_keys => [
        compartment => {
            class       => 'ModelSEED::DB::Compartment',
            key_columns => { compartment_uuid => 'uuid' },
        },
        
        compound => {
            class       => 'ModelSEED::DB::Compound',
            key_columns => { compound_uuid => 'uuid' },
        },
        
        reaction => {
            class       => 'ModelSEED::DB::Reaction',
            key_columns => { reaction_uuid => 'uuid' },
        },

        reaction_rule => {
            class       => 'ModelSEED::DB::ReactionRule',
            key_columns => { reaction_rule_uuid => 'uuid' },
        },
    ],
);

1;

