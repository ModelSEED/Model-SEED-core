package ModelSEED::DB::Reaction;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'reactions',

    columns => [
        uuid                => { type => 'character', length => 36, not_null => 1 },
        modDate             => { type => 'datetime' },
        locked              => { type => 'integer' },
        id                  => { type => 'varchar', length => 32, not_null => 1 },
        name                => { type => 'varchar', default => '\'\'', length => 255 },
        abbreviation        => { type => 'varchar', default => '\'\'', length => 255 },
        cksum               => { type => 'varchar', default => '\'\'', length => 255 },
        equation            => { type => 'text', default => '\'\'' },
        deltaG              => { type => 'scalar' },
        deltaGErr           => { type => 'scalar' },
        reversibility       => { type => 'character', default => '=', length => 1 },
        thermoReversibility => { type => 'character', length => 1 },
        defaultProtons      => { type => 'scalar' },
        compartment_uuid    => { type => 'character', length => 36 },
        defaultTransproton  => { type => 'scalar' },
    ],

    primary_key_columns => [ 'uuid' ],

    foreign_keys => [
        compartment => {
            class       => 'ModelSEED::DB::Compartment',
            key_columns => { compartment_uuid => 'uuid' },
        },
    ],

    relationships => [
        biochemistries => {
            map_class => 'ModelSEED::DB::BiochemistryReaction',
            map_from  => 'reaction',
            map_to    => 'biochemistry',
            type      => 'many to many',
        },

        compartments => {
            map_class => 'ModelSEED::DB::ReagentTransport',
            map_from  => 'reaction',
            map_to    => 'compartment',
            type      => 'many to many',
        },

        model_reaction_transports => {
            class      => 'ModelSEED::DB::ModelReactionTransport',
            column_map => { uuid => 'reaction_uuid' },
            type       => 'one to many',
        },

        model_reactions => {
            class      => 'ModelSEED::DB::ModelReaction',
            column_map => { uuid => 'reaction_uuid' },
            type       => 'one to many',
        },

        modelfbas => {
            map_class => 'ModelSEED::DB::ModelfbaReaction',
            map_from  => 'reaction',
            map_to    => 'modelfba',
            type      => 'many to many',
        },

        reaction_aliases => {
            class      => 'ModelSEED::DB::ReactionAlias',
            column_map => { uuid => 'reaction_uuid' },
            type       => 'one to many',
        },

        reaction_rule_transports => {
            class      => 'ModelSEED::DB::ReactionRuleTransport',
            column_map => { uuid => 'reaction_uuid' },
            type       => 'one to many',
        },

        reaction_rules => {
            class      => 'ModelSEED::DB::ReactionRule',
            column_map => { uuid => 'reaction_uuid' },
            type       => 'one to many',
        },

        reactionsets => {
            map_class => 'ModelSEED::DB::ReactionsetReaction',
            map_from  => 'reaction',
            map_to    => 'reactionset',
            type      => 'many to many',
        },

        reagents => {
            class      => 'ModelSEED::DB::Reagent',
            column_map => { uuid => 'reaction_uuid' },
            type       => 'one to many',
        },
    ],
);

1;

