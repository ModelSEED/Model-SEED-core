package ModelSEED::DB::ModelessFeature;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'modeless_features',

    columns => [
        modelfba_uuid  => { type => 'character', length => 36, not_null => 1 },
        feature_uuid   => { type => 'character', length => 36, not_null => 1 },
        modDate        => { type => 'datetime' },
        growthFraction => { type => 'scalar' },
        essential      => { type => 'integer' },
    ],

    primary_key_columns => [ 'modelfba_uuid', 'feature_uuid' ],

    foreign_keys => [
        feature => {
            class       => 'ModelSEED::DB::Feature',
            key_columns => { feature_uuid => 'uuid' },
        },

        modelfba => {
            class       => 'ModelSEED::DB::Modelfba',
            key_columns => { modelfba_uuid => 'uuid' },
        },
    ],
);

1;

