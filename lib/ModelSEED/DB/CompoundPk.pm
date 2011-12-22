package ModelSEED::DB::CompoundPk;

use strict;
use DateTime;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'compound_pk',

    columns => [
        compound => { type => 'character', length => 36, not_null => 1 },
        modDate  => { type => 'varchar', length => 45 },
        atom     => { type => 'integer' },
        pk       => { type => 'scalar', length => 64 },
        type     => { type => 'character', length => 1 },
    ],

    primary_key_columns => [ 'compound' ],

    foreign_keys => [
        compound_obj => {
            class       => 'ModelSEED::DB::Compound',
            key_columns => { compound => 'uuid' },
            rel_type    => 'one to one',
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

