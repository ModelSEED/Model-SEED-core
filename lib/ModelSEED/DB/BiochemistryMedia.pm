package ModelSEED::DB::BiochemistryMedia;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'biochemistry_media',

    columns => [
        biochemistry_uuid => { type => 'character', length => 36, not_null => 1 },
        media_uuid        => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'biochemistry_uuid', 'media_uuid' ],

    foreign_keys => [
        biochemistry => {
            class       => 'ModelSEED::DB::Biochemistry',
            key_columns => { biochemistry_uuid => 'uuid' },
        },

        media => {
            class       => 'ModelSEED::DB::Media',
            key_columns => { media_uuid => 'uuid' },
        },
    ],
);

1;

