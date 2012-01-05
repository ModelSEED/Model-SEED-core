package ModelSEED::DB::ComplexRole;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'complex_roles',

    columns => [
        complex_uuid => { type => 'character', length => 36, not_null => 1 },
        role_uuid    => { type => 'character', length => 36, not_null => 1 },
        optional     => { type => 'integer' },
        type         => { type => 'character', length => 1 },
    ],

    primary_key_columns => [ 'complex_uuid', 'role_uuid' ],

    foreign_keys => [
        complex => {
            class       => 'ModelSEED::DB::Complex',
            key_columns => { complex_uuid => 'uuid' },
        },

        role => {
            class       => 'ModelSEED::DB::Role',
            key_columns => { role_uuid => 'uuid' },
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

