package ModelSEED::DB::ModelReactionRawGPR;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'model_reaction_raw_gprs',

    columns => [
        model_uuid             => { type => 'character', length => 36, not_null => 1 },
        reaction_uuid          => { type => 'character', length => 36, not_null => 1 },
        model_compartment_uuid => { type => 'character', length => 36, not_null => 1 },
        isCustomGPR            => { type => 'integer' },
        rawGPR                 => { type => 'text', default => '' },
    ],

    primary_key_columns => [ 'model_uuid', 'reaction_uuid', 'model_compartment_uuid' ],

    foreign_keys => [
        model => {
            class       => 'ModelSEED::DB::Model',
            key_columns => { model_uuid => 'uuid' },
        },

        model_compartment => {
            class       => 'ModelSEED::DB::ModelCompartment',
            key_columns => { model_compartment_uuid => 'uuid' },
        },

        reaction => {
            class       => 'ModelSEED::DB::Reaction',
            key_columns => { reaction_uuid => 'uuid' },
        },
        model_reaction => {
            class       => 'ModelSEED::DB::ModelReaction',
            key_columns => {
                model_uuid => 'model_uuid',
                reaction_uuid => 'reaction_uuid',
                model_compartment_uuid => 'model_compartment_uuid',
            },
        },
                
    ],
);

1;
