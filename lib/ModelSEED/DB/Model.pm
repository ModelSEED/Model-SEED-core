package ModelSEED::DB::Model;


use strict;
use Data::UUID;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'models',

    columns => [
        uuid              => { type => 'character', length => 36, not_null => 1 },
        modDate           => { type => 'datetime' },
        locked            => { type => 'integer' },
        public            => { type => 'integer' },
        id                => { type => 'varchar', length => 255 },
        name              => { type => 'varchar', length => 32 },
        version           => { type => 'integer' },
        type              => { type => 'varchar', length => 32 },
        status            => { type => 'varchar', length => 32 },
        reactions         => { type => 'integer' },
        compounds         => { type => 'integer' },
        annotations       => { type => 'integer' },
        growth            => { type => 'scalar' },
        current           => { type => 'integer' },
        mapping_uuid      => { type => 'character', length => 36, not_null => 1 },
        biochemistry_uuid => { type => 'character', length => 36, not_null => 1 },
        annotation_uuid   => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'uuid' ],

    foreign_keys => [
        annotation => {
            class       => 'ModelSEED::DB::Annotation',
            key_columns => { annotation_uuid => 'uuid' },
        },

        biochemistry => {
            class       => 'ModelSEED::DB::Biochemistry',
            key_columns => { biochemistry_uuid => 'uuid' },
        },

        mapping => {
            class       => 'ModelSEED::DB::Mapping',
            key_columns => { mapping_uuid => 'uuid' },
        },
    ],

    relationships => [
        biomasses => {
            map_class => 'ModelSEED::DB::ModelBiomass',
            map_from  => 'model',
            map_to    => 'biomass',
            type      => 'many to many',
        },

        children => {
            map_class => 'ModelSEED::DB::ModelParent',
            map_from  => 'parent',
            map_to    => 'child',
            type      => 'many to many',
        },

        model_compartments => {
            class => 'ModelSEED::DB::ModelCompartment',
            column_map => { uuid => 'model_uuid' },
            type      => 'one to many',
        },

        model_aliases => {
            class      => 'ModelSEED::DB::ModelAlias',
            column_map => { uuid => 'model_uuid' },
            type       => 'one to many',
        },

        model_reaction_transports => {
            class      => 'ModelSEED::DB::ModelReactionTransport',
            column_map => { uuid => 'model_uuid' },
            type       => 'one to many',
        },

        model_reactions => {
            class      => 'ModelSEED::DB::ModelReaction',
            column_map => { uuid => 'model_uuid' },
            type       => 'one to many',
        },

        modelfbas => {
            class      => 'ModelSEED::DB::Modelfba',
            column_map => { uuid => 'model_uuid' },
            type       => 'one to many',
        },

        parents => {
            map_class => 'ModelSEED::DB::ModelParent',
            map_from  => 'child',
            map_to    => 'parent',
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
