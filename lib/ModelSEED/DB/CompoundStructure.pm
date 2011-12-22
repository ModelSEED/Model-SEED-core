package ModelSEED::DB::CompoundStructure;

use strict;
use DateTime;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'compound_structure',

    columns => [
        compound => { type => 'character', length => 36, not_null => 1 },
        modDate  => { type => 'varchar', length => 45 },
        type     => { type => 'varchar', length => 32, not_null => 1 },
        structure    => { type => 'text' },
    ],

    primary_key_columns => [ 'type', 'structure' ],

    foreign_keys => [
        compound_obj => {
            class       => 'ModelSEED::DB::Compound',
            key_columns => { compound => 'uuid' },
        },
    ],
);

__PACKAGE__->meta->column('modDate')->add_trigger(
    deflate => sub {
        unless(defined($_[0]->modDate)) {
            return DateTime->now();
        }
});

1;

