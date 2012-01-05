package ModelSEED::DB::ModelBiomass;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'model_biomass',

    columns => [
        model_uuid   => { type => 'character', length => 36, not_null => 1 },
        biomass_uuid => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'model_uuid', 'biomass_uuid' ],

    foreign_keys => [
        biomass => {
            class       => 'ModelSEED::DB::Biomass',
            key_columns => { biomass_uuid => 'uuid' },
        },

        model => {
            class       => 'ModelSEED::DB::Model',
            key_columns => { model_uuid => 'uuid' },
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

