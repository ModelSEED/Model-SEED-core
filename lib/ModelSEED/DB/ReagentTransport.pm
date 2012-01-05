package ModelSEED::DB::ReagentTransport;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'reagent_transports',

    columns => [
        reaction_uuid    => { type => 'character', length => 36, not_null => 1 },
        compartment_uuid => { type => 'character', length => 36, not_null => 1 },
        compartmentIndex => { type => 'integer', not_null => 1 },
    ],

    primary_key_columns => [ 'reaction_uuid', 'compartmentIndex' ],

    foreign_keys => [
        defaultCompartment => {
            class       => 'ModelSEED::DB::Compartment',
            key_columns => { compartment_uuid => 'uuid' },
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

