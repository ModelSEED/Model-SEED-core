package ModelSEED::DB::Role;


use strict;
use Data::UUID;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'roles',

    columns => [
        uuid         => { type => 'character', length => 36, not_null => 1 },
        modDate      => { type => 'datetime' },
        locked       => { type => 'integer' },
        id           => { type => 'varchar', length => 32 },
        name         => { type => 'varchar', length => 255 },
        searchname   => { type => 'varchar', length => 255 },
        feature_uuid => { type => 'character', length => 36 },
    ],

    primary_key_columns => [ 'uuid' ],

    foreign_keys => [
        exemplar => {
            class       => 'ModelSEED::DB::Feature',
            key_columns => { feature_uuid => 'uuid' },
        },
    ],

    relationships => [
        annotation_features => {
            class      => 'ModelSEED::DB::AnnotationFeature',
            column_map => { uuid => 'role_uuid' },
            type       => 'one to many',
        },

        complexes => {
            map_class => 'ModelSEED::DB::ComplexRole',
            map_from  => 'role',
            map_to    => 'complex',
            type      => 'many to many',
        },
    
        complex_roles => {
            class => 'ModelSEED::DB::ComplexRole',
            column_map => { uuid => 'role_uuid' },
            type => 'one to many',
        },

        mappings => {
            map_class => 'ModelSEED::DB::MappingRole',
            map_from  => 'role',
            map_to    => 'mapping',
            type      => 'many to many',
        },

        rolesets => {
            map_class => 'ModelSEED::DB::RolesetRole',
            map_from  => 'role',
            map_to    => 'roleset',
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
