package ModelSEED::DB::BiochemistryAlias;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'biochemistry_aliases',

    columns => [
        biochemistry_uuid => { type => 'character', length => 36, not_null => 1 },
        username          => { type => 'character', length => 255, not_null => 1 },
        id                => { type => 'character', length => 255, not_null => 1 },
    ],

    primary_key_columns => [ 'username', 'id' ],

    foreign_keys => [
        biochemistry => {
            class       => 'ModelSEED::DB::Biochemistry',
            key_columns => { biochemistry_uuid => 'uuid' },
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

