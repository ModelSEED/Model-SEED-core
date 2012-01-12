package ModelSEED::DB::ModelfbaCompound;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'modelfba_compounds',

    columns => [
        modelfba_uuid => { type => 'character', length => 36, not_null => 1 },
        compound_uuid => { type => 'character', length => 36, not_null => 1 },
        min           => { type => 'scalar' },
        max           => { type => 'scalar' },
        class         => { type => 'character', length => 1 },
    ],

    primary_key_columns => [ 'modelfba_uuid', 'compound_uuid' ],

    foreign_keys => [
        compound => {
            class       => 'ModelSEED::DB::Compound',
            key_columns => { compound_uuid => 'uuid' },
        },

        modelfba => {
            class       => 'ModelSEED::DB::Modelfba',
            key_columns => { modelfba_uuid => 'uuid' },
        },
    ],
);

1;
