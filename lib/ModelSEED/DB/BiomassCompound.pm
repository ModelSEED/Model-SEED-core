package ModelSEED::DB::BiomassCompound;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'biomass_compounds',

    columns => [
        biomass_uuid     => { type => 'character', length => 36, not_null => 1 },
        compound_uuid    => { type => 'character', length => 36, not_null => 1 },
        compartment_uuid => { type => 'character', length => 36, not_null => 1 },
        coefficient      => { type => 'scalar' },
    ],

    primary_key_columns => [ 'biomass_uuid', 'compound_uuid' ],

    foreign_keys => [
        biomass => {
            class       => 'ModelSEED::DB::Biomass',
            key_columns => { biomass_uuid => 'uuid' },
        },

        compartment => {
            class       => 'ModelSEED::DB::ModelCompartment',
            key_columns => { compartment_uuid => 'uuid' },
        },

        compound => {
            class       => 'ModelSEED::DB::Compound',
            key_columns => { compound_uuid => 'uuid' },
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

