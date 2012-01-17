package ModelSEED::DB::BiochemistryAlias;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'biochemistry_aliases',

    columns => [
        biochemistry_uuid => { type => 'character', length => 36, not_null => 1 },
        username          => { type => 'varchar', length => 255, not_null => 1 },
        id                => { type => 'varchar', length => 255, not_null => 1 },
    ],

    primary_key_columns => [ 'username', 'id' ],

    foreign_keys => [
        biochemistry => {
            class       => 'ModelSEED::DB::Biochemistry',
            key_columns => { biochemistry_uuid => 'uuid' },
        },
    ],
);

1;
