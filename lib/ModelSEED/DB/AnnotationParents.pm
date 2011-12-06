package ModelSEED::DB::AnnotationParents;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'annotation_parents',

    columns => [
        parent => { type => 'character', length => 36, not_null => 1 },
        child  => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'child', 'parent' ],

    foreign_keys => [
        parent_obj => {
            class       => 'ModelSEED::DB::Annotation',
            key_columns => { parent => 'uuid' },
        },
        child_obj => {
            class       => 'ModelSEED::DB::Annotation',
            key_columns => { child => 'uuid' },
        },
    ],
);

1;

