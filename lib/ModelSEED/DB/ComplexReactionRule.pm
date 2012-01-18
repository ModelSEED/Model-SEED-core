package ModelSEED::DB::ComplexReactionRule;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'complex_reaction_rules',

    columns => [
        reaction_rule_uuid => { type => 'character', length => 36, not_null => 1 },
        complex_uuid       => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'reaction_rule_uuid', 'complex_uuid' ],

    foreign_keys => [
        complex => {
            class       => 'ModelSEED::DB::Complex',
            key_columns => { complex_uuid => 'uuid' },
        },

        reaction_rule => {
            class       => 'ModelSEED::DB::ReactionRule',
            key_columns => { reaction_rule_uuid => 'uuid' },
        },
    ],
);

1;

