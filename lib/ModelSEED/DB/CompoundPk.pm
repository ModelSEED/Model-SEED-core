package ModelSEED::DB::CompoundPk;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'compound_pks',

    columns => [
        compound_uuid => { type => 'character', length => 36, not_null => 1 },
        modDate       => { type => 'varchar', length => 45 },
        atom          => { type => 'integer' },
        pk            => { type => 'scalar' },
        type          => { type => 'character', length => 1 },
    ],

    primary_key_columns => [ 'compound_uuid', 'atom', 'type' ],

    foreign_keys => [
        compound => {
            class       => 'ModelSEED::DB::Compound',
            key_columns => { compound_uuid => 'uuid' },
            rel_type    => 'one to one',
        },
    ],
);

1;
