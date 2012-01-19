package ModelSEED::DB::ReactionRule;

use strict;
use Data::UUID;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'reaction_rules',

    columns => [
        uuid              => { type => 'character', length => 36, not_null => 1 },
        reaction_uuid     => { type => 'character', length => 36, not_null => 1 },
        compartment_uuid  => { type => 'character', length => 36, not_null => 1 },
        direction         => { type => 'character', length => 1 },
        transprotonNature => { type => 'character', length => 255 },
    ],

    primary_key_columns => [ 'uuid' ],

    foreign_keys => [
        compartment => {
            class       => 'ModelSEED::DB::Compartment',
            key_columns => { compartment_uuid => 'uuid' },
        },
        reaction => {
            class       => 'ModelSEED::DB::Reaction',
            key_columns => { reaction_uuid => 'uuid' },
        },
    ],

    relationships => [
        complexes => {
            map_class   => "ModelSEED::DB::ComplexReactionRule",
            map_from    => "reaction_rule",
            map_to      => "complex",
            type        => "many to many",
        },
        
        model_reactions => {
            class      => 'ModelSEED::DB::ModelReaction',
            column_map => { uuid => 'reaction_rule_uuid' },
            type       => 'one to many',
        },

        reaction_rule_transports => {
            class      => 'ModelSEED::DB::ReactionRuleTransport',
            column_map => { uuid => 'reaction_rule_uuid' },
            type       => 'one to many',
        },
        
        mappings => {
            map_class => 'ModelSEED::DB::MappingReactionRule',
            map_from  => 'reaction_rule',
            map_to    => 'mapping',
            type      => 'many to many',
        },
    ],
);

__PACKAGE__->meta->column('uuid')->add_trigger(
    deflate => sub {
        my $uuid = $_[0]->uuid;
        if(ref($uuid) && ref($uuid) eq 'Data::UUID') {
            return $uuid->to_string();
        } elsif($uuid) {
            return $uuid;
        } else {
            return Data::UUID->new()->create_str();
        }   
});

1;

