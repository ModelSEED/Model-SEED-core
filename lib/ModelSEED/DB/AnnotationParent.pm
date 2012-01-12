package ModelSEED::DB::AnnotationParent;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'annotation_parents',

    columns => [
        child_uuid  => { type => 'character', length => 36, not_null => 1 },
        parent_uuid => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'child_uuid', 'parent_uuid' ],

    foreign_keys => [
        child => {
            class       => 'ModelSEED::DB::Annotation',
            key_columns => { child_uuid => 'uuid' },
        },

        parent => {
            class       => 'ModelSEED::DB::Annotation',
            key_columns => { parent_uuid => 'uuid' },
        },
    ],
);

1;
