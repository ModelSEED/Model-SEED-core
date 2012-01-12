package ModelSEED::DB::MediaCompound;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'media_compounds',

    columns => [
        media_uuid    => { type => 'character', length => 36, not_null => 1 },
        compound_uuid => { type => 'character', length => 36, not_null => 1 },
        concentration => { type => 'scalar' },
        minflux       => { type => 'scalar' },
        maxflux       => { type => 'scalar' },
    ],

    primary_key_columns => [ 'media_uuid', 'compound_uuid' ],

    foreign_keys => [
        compound => {
            class       => 'ModelSEED::DB::Compound',
            key_columns => { compound_uuid => 'uuid' },
        },

        media => {
            class       => 'ModelSEED::DB::Media',
            key_columns => { media_uuid => 'uuid' },
        },
    ],
);

1;
