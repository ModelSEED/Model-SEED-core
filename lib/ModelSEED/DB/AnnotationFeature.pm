package ModelSEED::DB::AnnotationFeature;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'annotation_features',

    columns => [
        annotation_uuid => { type => 'character', length => 36, not_null => 1 },
        feature_uuid    => { type => 'character', length => 36, not_null => 1 },
        role_uuid       => { type => 'character', length => 36, not_null => 1 },
        complete_string => { type => 'text', default => '' }, 
    ],

    primary_key_columns => [ 'annotation_uuid', 'feature_uuid', 'role_uuid' ],

    foreign_keys => [
        annotation => {
            class       => 'ModelSEED::DB::Annotation',
            key_columns => { annotation_uuid => 'uuid' },
        },

        feature => {
            class       => 'ModelSEED::DB::Feature',
            key_columns => { feature_uuid => 'uuid' },
        },

        role => {
            class       => 'ModelSEED::DB::Role',
            key_columns => { role_uuid => 'uuid' },
        },
    ],
);

1;
