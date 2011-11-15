package ModelSEED::DB::MediaCompound;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'media_compound',

    columns => [
        media         => { type => 'character', length => 36, not_null => 1 },
        compound      => { type => 'character', length => 36, not_null => 1 },
        concentration => { type => 'scalar', length => 64 },
        minflux       => { type => 'scalar', length => 64 },
        maxflux       => { type => 'scalar', length => 64 },
    ],

    primary_key_columns => [ 'media', 'compound' ],

    foreign_keys => [
        compound_obj => {
            class       => 'ModelSEED::DB::Compound',
            key_columns => { compound => 'uuid' },
        },

        media_obj => {
            class       => 'ModelSEED::DB::Media',
            key_columns => { media => 'uuid' },
        },
    ],
);

1;

