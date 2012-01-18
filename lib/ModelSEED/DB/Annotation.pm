package ModelSEED::DB::Annotation;


use strict;
use Data::UUID;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'annotations',

    columns => [
        uuid        => { type => 'character', length => 36, not_null => 1 },
        modDate     => { type => 'datetime' },
        locked      => { type => 'integer' },
        name        => { type => 'varchar', length => 255 },
        genome_uuid => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'uuid' ],

    foreign_keys => [
        genome => {
            class       => 'ModelSEED::DB::Genome',
            key_columns => { genome_uuid => 'uuid' },
        },
    ],

    relationships => [
        annotation_features => {
            class      => 'ModelSEED::DB::AnnotationFeature',
            column_map => { uuid => 'annotation_uuid' },
            type       => 'one to many',
        },

        children => {
            map_class => 'ModelSEED::DB::AnnotationParent',
            map_from  => 'parent',
            map_to    => 'child',
            type      => 'many to many',
        },

        models => {
            class      => 'ModelSEED::DB::Model',
            column_map => { uuid => 'annotation_uuid' },
            type       => 'one to many',
        },

        parents => {
            map_class => 'ModelSEED::DB::AnnotationParent',
            map_from  => 'child',
            map_to    => 'parent',
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
