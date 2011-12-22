package ModelSEED::DB::Mapping;

use strict;
use Data::UUID;
use DateTime;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'mapping',

    columns => [
        uuid    => { type => 'character', length => 36, not_null => 1 },
        biochemistry => { type => 'character', length => 36, not_null => 1},
        modDate => { type => 'datetime' },
        locked  => { type => 'integer' },
        public  => { type => 'integer' },
        name    => { type => 'varchar', length => 255 },
    ],

    primary_key_columns => [ 'uuid' ],

    foreign_keys => [
        biochemistry_obj => {
            class => 'ModelSEED::DB::Biochemistry',
            key_columns => { biochemistry => 'uuid' },
        },
    ],

    relationships => [
        compartment => {
            map_class  => 'ModelSEED::DB::MappingCompartment',
            type       => 'many to many',
        },

        complexes => {
            map_class  => 'ModelSEED::DB::MappingComplex',
            type       => 'many to many',
        },

        role => {
            map_class  => 'ModelSEED::DB::MappingRole',
            type       => 'many to many',
        },

        model => {
            class      => 'ModelSEED::DB::Model',
            column_map => { uuid => 'mapping' },
            type       => 'one to many',
        },
        parents => {
            map_class  => 'ModelSEED::DB::MappingParents',
            map_from   => 'parent_obj',
            map_to     => 'child_obj',
            type       => 'many to many',
       },
       children => {
            map_class  => 'ModelSEED::DB::MappingParents',
            map_from   => 'child_obj',
            map_to     => 'parent_obj',
            type       => 'many to many',
       },
       alias => {
            class => 'ModelSEED::DB::MappingAlias',
            column_map => { uuid => 'mapping' },
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

