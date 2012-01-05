package ModelSEED::DB::ModelReactionTransport;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'model_reaction_transports',

    columns => [
        model_uuid             => { type => 'character', length => 36, not_null => 1 },
        reaction_uuid          => { type => 'character', length => 36, not_null => 1 },
        transportIndex         => { type => 'integer', not_null => 1 },
        model_compartment_uuid => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'model_uuid', 'reaction_uuid', 'transportIndex' ],

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

