package ModelSEED::DB::Compound;

use strict;
use Data::UUID;
use DateTime;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'compound',

    columns => [
        uuid             => { type => 'character', length => 36, not_null => 1 },
        modDate          => { type => 'datetime' },
        id               => { type => 'varchar', length => 32 },
        name             => { type => 'varchar', length => 255 },
        abbreviation     => { type => 'varchar', length => 255 },
        cksum            => { type => 'varchar', length => 255 },
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

        aliases => {
            class      => 'ModelSEED::DB::CompoundAlias',
            column_map => { uuid => 'compound' },
            type       => 'one to many',
        },
        
        structures => {
            class      => 'ModelSEED::DB::CompoundStructure',
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

__PACKAGE__->meta->column('uuid')->add_trigger(
    deflate => sub {
        my $uuid = $_[0]->uuid;
        if(ref($uuid) && ref($uuid) eq 'Data::UUID') {
            return $uuid->to_string();
        } elsif($uuid) {
            return $uuid;
        } else {
            return Data::UUID->new()->create_str();
        }   
});

__PACKAGE__->meta->column('modDate')->add_trigger(
    deflate => sub {
        unless(defined($_[0]->modDate)) {
            return DateTime->now();
        }
});

1;

