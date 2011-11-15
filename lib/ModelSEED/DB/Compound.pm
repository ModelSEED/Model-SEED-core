package ModelSEED::DB::Compound;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'compound',

    columns => [
        uuid             => { type => 'character', length => 36, not_null => 1 },
        modDate          => { type => 'datetime' },
        id               => { type => 'varchar', length => 32 },
        name             => { type => 'varchar', length => 255 },
        abbreviation     => { type => 'varchar', length => 32 },
        md5              => { type => 'varchar', length => 255 },
        unchargedFormula => { type => 'varchar', length => 255 },
        formula          => { type => 'varchar', length => 255 },
        mass             => { type => 'scalar', length => 64 },
        defaultCharge    => { type => 'scalar', length => 64 },
        deltaG           => { type => 'scalar', length => 64 },
        deltaGErr        => { type => 'scalar', length => 64 },
    ],

    primary_key_columns => [ 'uuid' ],

    relationships => [
        biochemistry_compound => {
            class      => 'ModelSEED::DB::BiochemistryCompound',
            column_map => { uuid => 'compound' },
            type       => 'one to many',
        },

        compound_alias => {
            class      => 'ModelSEED::DB::CompoundAlia',
            column_map => { uuid => 'compound' },
            type       => 'one to many',
        },

        compound_pk => {
            class                => 'ModelSEED::DB::CompoundPk',
            column_map           => { uuid => 'compound' },
            type                 => 'one to one',
            with_column_triggers => '0',
        },

        compoundset_compound => {
            class      => 'ModelSEED::DB::CompoundsetCompound',
            column_map => { uuid => 'compound' },
            type       => 'one to many',
        },

        media_compound => {
            class      => 'ModelSEED::DB::MediaCompound',
            column_map => { uuid => 'compound' },
            type       => 'one to many',
        },

        modelfba_compound => {
            class      => 'ModelSEED::DB::ModelfbaCompound',
            column_map => { uuid => 'compound' },
            type       => 'one to many',
        },

        reaction_compound => {
            class      => 'ModelSEED::DB::ReactionCompound',
            column_map => { uuid => 'compound' },
            type       => 'one to many',
        },
    ],
);

1;

