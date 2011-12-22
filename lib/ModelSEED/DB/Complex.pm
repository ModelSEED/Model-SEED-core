package ModelSEED::DB::Complex;

use strict;
use Data::UUID;
use DateTime;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'complex',

    columns => [
        uuid       => { type => 'character', length => 36, not_null => 1 },
        modDate    => { type => 'datetime' },
        id         => { type => 'varchar', length => 32 },
        name       => { type => 'varchar', length => 255 },
        searchname => { type => 'varchar', length => 255 },
    ],

    primary_key_columns => [ 'uuid' ],

    relationships => [
        complex_role => {
            class      => 'ModelSEED::DB::ComplexRole',
            column_map => { uuid => 'complex'},
            type       => 'one to many',
        },

        mapping_complex => {
            map_class  => 'ModelSEED::DB::MappingComplex',
            type       => 'many to many',
        },

        reaction_complex => {
            class      => 'ModelSEED::DB::ReactionComplex',
            column_map => { uuid => 'complex' },
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
    deflate => sub {
        unless(defined($_[0]->modDate)) {
            return DateTime->now();
        }
});

1;

