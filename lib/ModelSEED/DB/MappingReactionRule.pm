package ModelSEED::DB::MappingReactionRule;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'mapping_reaction_rules',

    columns => [
        reaction_rule_uuid => { type => 'character', length => 36, not_null => 1 },
        mapping_uuid       => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'reaction_rule_uuid', 'mapping_uuid' ],

    foreign_keys => [
        mapping => {
            class       => 'ModelSEED::DB::Mapping',
            key_columns => { mapping_uuid => 'uuid' },
        },

        reaction_rule => {
            class       => 'ModelSEED::DB::ReactionRule',
            key_columns => { reaction_rule_uuid => 'uuid' },
        },
    ],
);

1;

