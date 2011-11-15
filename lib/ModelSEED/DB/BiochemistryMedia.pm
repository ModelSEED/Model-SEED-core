package ModelSEED::DB::BiochemistryMedia;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'biochemistry_media',

    columns => [
        biochemistry => { type => 'character', length => 36, not_null => 1 },
        media        => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'biochemistry', 'media' ],

    foreign_keys => [
        biochemistry_obj => {
            class       => 'ModelSEED::DB::Biochemistry',
            key_columns => { biochemistry => 'uuid' },
        },

        media_obj => {
            class       => 'ModelSEED::DB::Media',
            key_columns => { media => 'uuid' },
        },
    ],
);

1;

