package ModelSEED::DB::Reagent;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'reagents',

    columns => [
        reaction_uuid    => { type => 'character', length => 36, not_null => 1 },
        compound_uuid    => { type => 'character', length => 36, not_null => 1 },
        compartmentIndex => { type => 'integer', not_null => 1 },
        coefficient      => { type => 'scalar' },
        cofactor         => { type => 'integer' },
    ],

    primary_key_columns => [ 'reaction_uuid', 'compound_uuid', 'compartmentIndex' ],

    foreign_keys => [
        compound => {
            class       => 'ModelSEED::DB::Compound',
            key_columns => { compound_uuid => 'uuid' },
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

