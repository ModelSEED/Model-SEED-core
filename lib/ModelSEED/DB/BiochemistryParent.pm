package ModelSEED::DB::BiochemistryParent;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'biochemistry_parents',

    columns => [
        child_uuid  => { type => 'character', length => 36, not_null => 1 },
        parent_uuid => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'child_uuid', 'parent_uuid' ],

    foreign_keys => [
        child => {
            class       => 'ModelSEED::DB::Biochemistry',
            key_columns => { child_uuid => 'uuid' },
        },

        parent => {
            class       => 'ModelSEED::DB::Biochemistry',
            key_columns => { parent_uuid => 'uuid' },
        },
    ],
);

1;
