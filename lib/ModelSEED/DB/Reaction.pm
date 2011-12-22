package ModelSEED::DB::Reaction;

use strict;
use Data::UUID;
use DateTime;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'reaction',

    columns => [
        uuid                => { type => 'character', length => 36, not_null => 1 },
        modDate             => { type => 'datetime' },
        id                  => { type => 'varchar', length => 32 },
        name                => { type => 'varchar', length => 255 },
        abbreviation        => { type => 'varchar', length => 255 },
        cksum               => { type => 'varchar', length => 255 },
        equation            => { type => 'text' },
        deltaG              => { type => 'scalar', length => 64 },
        deltaGErr           => { type => 'scalar', length => 64 },
        reversibility       => { type => 'character', length => 1 },
        thermoReversibility => { type => 'character', length => 1 },
        defaultProtons      => { type => 'scalar', length => 64 },
        defaultIN           => { type => 'character', length => 36 },
        defaultOUT          => { type => 'character', length => 36 },
        defaultTransproton  => { type => 'scalar', length => 64 },
    ],

    primary_key_columns => [ 'uuid' ],

    foreign_keys => [
        compartment => {
            class       => 'ModelSEED::DB::Compartment',
            key_columns => { defaultOUT => 'uuid' },
        },

        compartment_obj => {
            class       => 'ModelSEED::DB::Compartment',
            key_columns => { defaultIN => 'uuid' },
        },
    ],

    relationships => [
        biochemistry_reaction => {
            class      => 'ModelSEED::DB::BiochemistryReaction',
            column_map => { uuid => 'reaction' },
            type       => 'one to many',
        },

        model_reaction => {
            class      => 'ModelSEED::DB::ModelReaction',
            column_map => { uuid => 'reaction' },
            type       => 'one to many',
        },

        modelfba_reaction => {
            class      => 'ModelSEED::DB::ModelfbaReaction',
            column_map => { uuid => 'reaction' },
            type       => 'one to many',
        },

        reaction_alias => {
            class      => 'ModelSEED::DB::ReactionAlias',
            column_map => { uuid => 'reaction' },
            type       => 'one to many',
        },

        reaction_complex => {
            class      => 'ModelSEED::DB::ReactionComplex',
            column_map => { uuid => 'reaction' },
            type       => 'one to many',
        },

        reaction_compound => {
            class      => 'ModelSEED::DB::ReactionCompound',
            column_map => { uuid => 'reaction' },
            type       => 'one to many',
        },

        reactionset_reaction => {
            class      => 'ModelSEED::DB::ReactionsetReaction',
            column_map => { uuid => 'reaction' },
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
    deflate => sub {
        unless(defined($_[0]->modDate)) {
            return DateTime->now();
        }
});
1;

