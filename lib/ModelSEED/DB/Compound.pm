package ModelSEED::DB::Compound;
use strict;
use Data::UUID;
use DateTime;
use ModelSEED::ApiHelpers;
use base qw(ModelSEED::DB::DB::Object::AutoBase2);

sub default {
    return {
	columns => "*",
	with_rels => ["compound_aliases"],
	ref_rels => []
    }
}

sub serialize {
    my ($self, $args, $ctx) = @_;
    my $hash = {};
    ModelSEED::ApiHelpers::serializeAttributes(
        $self, [$self->meta->columns], $hash);
    my $aliases = [];
    foreach my $alias ($self->compound_aliases) {
        push(@$aliases, { type => $alias->type, alias => $alias->alias});
    }
    $hash->{compound_aliases} = $aliases;
    return $hash;
}

    


__PACKAGE__->meta->setup(
    table   => 'compounds',

    columns => [
        uuid             => { type => 'character', length => 36, not_null => 1 },
        modDate          => { type => 'datetime' },
        locked           => { type => 'integer' },
        id               => { type => 'varchar', length => 32 },
        name             => { type => 'varchar', length => 255 },
        abbreviation     => { type => 'varchar', length => 255 },
        cksum            => { type => 'varchar', length => 255 },
        unchargedFormula => { type => 'varchar', length => 255 },
        formula          => { type => 'varchar', length => 255 },
        mass             => { type => 'scalar' },
        defaultCharge    => { type => 'scalar' },
        deltaG           => { type => 'scalar' },
        deltaGErr        => { type => 'scalar' },
    ],

    primary_key_columns => [ 'uuid' ],

    relationships => [
        biochemistries => {
            map_class => 'ModelSEED::DB::BiochemistryCompound',
            map_from  => 'compound',
            map_to    => 'biochemistry',
            type      => 'many to many',
        },

        biomass_compounds => {
            class      => 'ModelSEED::DB::BiomassCompound',
            column_map => { uuid => 'compound_uuid' },
            type       => 'one to many',
        },

        compound_aliases => {
            class      => 'ModelSEED::DB::CompoundAlias',
            column_map => { uuid => 'compound_uuid' },
            type       => 'one to many',
        },

        compound_pk => {
            class                => 'ModelSEED::DB::CompoundPk',
            column_map           => { uuid => 'compound_uuid' },
            type                 => 'one to one',
            with_column_triggers => '0',
        },

        compound_structures => {
            class      => 'ModelSEED::DB::CompoundStructure',
            column_map => { uuid => 'compound_uuid' },
            type       => 'one to many',
        },

        compoundsets => {
            map_class => 'ModelSEED::DB::CompoundsetCompound',
            map_from  => 'compound',
            map_to    => 'compoundset',
            type      => 'many to many',
        },

        media => {
            map_class => 'ModelSEED::DB::MediaCompound',
            map_from  => 'compound',
            map_to    => 'media',
            type      => 'many to many',
        },

        modelfbas => {
            map_class => 'ModelSEED::DB::ModelfbaCompound',
            map_from  => 'compound',
            map_to    => 'modelfba',
            type      => 'many to many',
        },

        reagents => {
            class      => 'ModelSEED::DB::Reagent',
            column_map => { uuid => 'compound_uuid' },
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
   on_save => sub { return DateTime->now() });

1;

