package ModelSEED::DB::ModelessFeature;

use strict;
use DateTime;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'modeless_feature',

    columns => [
        modelfba       => { type => 'character', length => 36, not_null => 1 },
        feature        => { type => 'character', length => 36, not_null => 1 },
        modDate        => { type => 'datetime' },
        growthFraction => { type => 'scalar', length => 64 },
        essential      => { type => 'integer' },
    ],

    primary_key_columns => [ 'modelfba', 'feature' ],

    foreign_keys => [
        feature_obj => {
            class       => 'ModelSEED::DB::Feature',
            key_columns => { feature => 'uuid' },
        },

        modelfba_obj => {
            class       => 'ModelSEED::DB::Modelfba',
            key_columns => { modelfba => 'uuid' },
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

