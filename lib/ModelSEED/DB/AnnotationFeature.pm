package ModelSEED::DB::AnnotationFeature;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'annotation_features',

    columns => [
        annotation_uuid => { type => 'character', length => 36, not_null => 1 },
        feature_uuid    => { type => 'character', length => 36, not_null => 1 },
        role_uuid       => { type => 'character', length => 36, not_null => 1 },
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

