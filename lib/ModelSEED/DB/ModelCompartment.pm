package ModelSEED::DB::ModelCompartment;

use strict;
use DateTime;
use Data::UUID;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'model_compartments',

    columns => [
        uuid             => { type => 'character', length => 36, not_null => 1 },
        modDate          => { type => 'datetime', not_null => 1 },
        locked           => { type => 'integer' },
        model_uuid       => { type => 'character', length => 36, not_null => 1 },
        compartment_uuid => { type => 'character', length => 36, not_null => 1 },
        compartmentIndex => { type => 'integer', not_null => 1 },
        label            => { type => 'varchar', length => 255 },
        pH               => { type => 'scalar' },
        potential        => { type => 'scalar' },
    ],

    primary_key_columns => [ 'uuid' ],

    foreign_keys => [
        compartment => {
            class       => 'ModelSEED::DB::Compartment',
            key_columns => { compartment_uuid => 'uuid' },
        },

        model => {
            class       => 'ModelSEED::DB::Model',
            key_columns => { model_uuid => 'uuid' },
        },
    ],

    relationships => [
        biomass_compounds => {
            class      => 'ModelSEED::DB::BiomassCompound',
            column_map => { uuid => 'compartment_uuid' },
            type       => 'one to many',
        },

        model_reaction_transports => {
            class      => 'ModelSEED::DB::ModelReactionTransport',
            column_map => { uuid => 'modelcompartment_uuid' },
            type       => 'one to many',
        },

        model_reactions => {
            class      => 'ModelSEED::DB::ModelReaction',
            column_map => { uuid => 'modelcompartment_uuid' },
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
   on_save => sub { $_[0]->modDate(DateTime->now()); });
        


1;
