package ModelSEED::DB::BiochemistryCompoundset;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'biochemistry_compoundsets',

    columns => [
        biochemistry_uuid => { type => 'character', length => 36, not_null => 1 },
        compoundset_uuid  => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'biochemistry_uuid', 'compoundset_uuid' ],

    foreign_keys => [
        biochemistry => {
            class       => 'ModelSEED::DB::Biochemistry',
            key_columns => { biochemistry_uuid => 'uuid' },
        },

        compoundset => {
            class       => 'ModelSEED::DB::Compoundset',
            key_columns => { compoundset_uuid => 'uuid' },
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

