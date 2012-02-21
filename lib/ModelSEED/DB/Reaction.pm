package ModelSEED::DB::Reaction;
use strict;
use Data::UUID;
use DateTime;
use ModelSEED::ApiHelpers;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

sub default {
    return {
	columns       => "*",
	relationships => ["reagents", "reaction_aliases"]
    }
}

sub serialize {
    my ($self, $args, $ctx) = @_;
    my $hash = {};
    ModelSEED::ApiHelpers::serializeAttributes($self,
        [$self->meta->columns], $hash);
    ModelSEED::ApiHelpers::inlineRelationships($self,
        { reagents => 1,
          reaction_aliases => sub {
            my ($obj, $args, $ctx) = @_;    
            return { type => $obj->type, alias => $obj->alias };
          },
        }, $hash, $args, $ctx);
    return $hash;
}

sub deserialize {
    my ($self, $payload, $args, $ctx, $method) = @_;
    # apply basic attributes from payload to self
    # apply reference attributes if they are "different"
    #   dereference, then apply
}

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
        defaultCompartment => {
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

        default_transported_reagents => {
            class      => 'ModelSEED::DB::DefaultTransportedReagent',
            column_map => { uuid => 'reaction_uuid' },
            type       => 'one to many',
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

__PACKAGE__->meta->column('modDate')->add_trigger(
   on_save => sub { return DateTime->now() });

1;

