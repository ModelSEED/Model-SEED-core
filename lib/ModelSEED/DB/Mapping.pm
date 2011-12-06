package ModelSEED::DB::Mapping;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'mapping',

    columns => [
        uuid    => { type => 'character', length => 36, not_null => 1 },
        modDate => { type => 'datetime' },
        locked  => { type => 'integer' },
        public  => { type => 'integer' },
        name    => { type => 'varchar', length => 255 },
    ],

    primary_key_columns => [ 'uuid' ],

    relationships => [
        mapping_compartment => {
            class      => 'ModelSEED::DB::MappingCompartment',
            column_map => { uuid => 'mapping' },
            type       => 'one to many',
        },

        mapping_complex => {
            class      => 'ModelSEED::DB::MappingComplex',
            column_map => { uuid => 'mapping' },
            type       => 'one to many',
        },

        mapping_role => {
            class      => 'ModelSEED::DB::MappingRole',
            column_map => { uuid => 'mapping' },
            type       => 'one to many',
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
    ],
);

1;

