package ModelSEED::DB::Role;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'role',

    columns => [
        uuid       => { type => 'character', length => 36, not_null => 1 },
        modDate    => { type => 'datetime' },
        id         => { type => 'varchar', length => 32 },
        name       => { type => 'varchar', length => 255 },
        searchname => { type => 'varchar', length => 255 },
        exemplar   => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'uuid' ],

    foreign_keys => [
        feature => {
            class       => 'ModelSEED::DB::Feature',
            key_columns => { exemplar => 'uuid' },
        },
    ],

    relationships => [
        annotation_feature => {
            class      => 'ModelSEED::DB::AnnotationFeature',
            column_map => { uuid => 'role' },
            type       => 'one to many',
        },

        complex_role => {
            class      => 'ModelSEED::DB::ComplexRole',
            column_map => { uuid => 'role' },
            type       => 'one to many',
        },

        mapping_role => {
            class      => 'ModelSEED::DB::MappingRole',
            column_map => { uuid => 'role' },
            type       => 'one to many',
        },

        roleset_role => {
            class      => 'ModelSEED::DB::RolesetRole',
            column_map => { uuid => 'role' },
            type       => 'one to many',
        },
    ],
);

1;

