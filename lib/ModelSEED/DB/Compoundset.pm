package ModelSEED::DB::Compoundset;


use strict;
use Data::UUID;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'compoundsets',

    columns => [
        uuid       => { type => 'character', length => 36, not_null => 1 },
        modDate    => { type => 'datetime' },
        locked     => { type => 'integer' },
        id         => { type => 'varchar', length => 32 },
        name       => { type => 'varchar', length => 255 },
        searchname => { type => 'varchar', length => 255 },
        class      => { type => 'varchar', length => 255 },
        type       => { type => 'varchar', length => 32 },
    ],

    primary_key_columns => [ 'uuid' ],

    relationships => [
        biochemistries => {
            map_class => 'ModelSEED::DB::BiochemistryCompoundset',
            map_from  => 'compoundset',
            map_to    => 'biochemistry',
            type      => 'many to many',
        },

        compounds => {
            map_class => 'ModelSEED::DB::CompoundsetCompound',
            map_from  => 'compoundset',
            map_to    => 'compound',
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

