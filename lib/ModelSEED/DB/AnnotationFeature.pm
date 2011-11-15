package ModelSEED::DB::AnnotationFeature;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'annotation_feature',

    columns => [
        annotation => { type => 'character', length => 36, not_null => 1 },
        feature    => { type => 'character', length => 36, not_null => 1 },
        role       => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'annotation', 'feature', 'role' ],

    foreign_keys => [
        annotation_obj => {
            class       => 'ModelSEED::DB::Annotation',
            key_columns => { annotation => 'uuid' },
        },

        feature_obj => {
            class       => 'ModelSEED::DB::Feature',
            key_columns => { feature => 'uuid' },
        },

        role_obj => {
            class       => 'ModelSEED::DB::Role',
            key_columns => { role => 'uuid' },
        },
    ],
);

1;

