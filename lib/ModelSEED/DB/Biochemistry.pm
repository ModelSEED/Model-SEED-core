package ModelSEED::DB::Biochemistry;
use strict;
use Data::UUID;
use ModelSEED::ApiHelpers qw(serializeAttributes serializeRelationships);

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

sub default {
    return {
	columns       => "*",
	relationships => [],
	references    => [ qw( reactions compounds reactionsets compoundsets
            media compartments parents children )]
    }
}

sub serialize {
    my ($self, $args, $ctx) = @_;
    my $hash = {};
    ModelSEED::ApiHelpers::serializeAttributes(
        $self, [$self->meta->columns], $hash);
    my $rels = [ qw( reactions compounds reactionsets compoundsets
        media compartments parents children )];
    ModelSEED::ApiHelpers::serializeRelationships(
        $self, $rels, $hash, $args, $ctx);
    return $hash;
}    

sub deserialize {
    my ($self, $obj, $args, $ctx) = @_;
    foreach my $columnName ($self->meta->column_names) {
        $self->$columnName = $obj->{$columnName} || undef;
    }
    foreach my $relationship ($self->meta->relationships) {
        my $name = $relationship->name;
        if(defined($obj->{$name}) && ref($obj->{$name}) eq "ARRAY") {
            $self->$name = [];
            my $array = [];
            foreach my $relObject ($obj->{$name}) {
                if(ref($relObject) eq 'HASH') {
                    $relObject = $ctx->deserialize(
                        $self->reference("biochem/".$self->uuid, $obj),
                        $obj);
                } else {
                    $relObject = $ctx->dereference($relObject);
                }
                push(@$array, $relObject);
            }
            $self->$name = $array;
        } elsif(defined($obj->{$name})) {
            my $ref = $obj->{$name};
            my $relObjects = $ctx->dereference($ref);
            $self->$name = $relObjects;
        } else {
            $self->$name = [];
        }
    }
    return $self;
}

        

        
    

__PACKAGE__->meta->setup(
    table   => 'biochemistries',

    columns => [
        uuid    => { type => 'character', length => 36, not_null => 1 },
        modDate => { type => 'datetime' },
        locked  => { type => 'integer' },
        public  => { type => 'integer' },
        name    => { type => 'varchar', length => 255 },
    ],

    primary_key_columns => [ 'uuid' ],

    relationships => [
        biochemistry_aliases => {
            class      => 'ModelSEED::DB::BiochemistryAlias',
            column_map => { uuid => 'biochemistry_uuid' },
            type       => 'one to many',
        },

        media => {
            map_class  => 'ModelSEED::DB::BiochemistryMedia',
            map_from   => 'biochemistry',
            map_to     => 'media',
            type       => 'many to many',
        },

        children => {
            map_class => 'ModelSEED::DB::BiochemistryParent',
            map_from  => 'parent',
            map_to    => 'child',
            type      => 'many to many',
        },

        compartments => {
            map_class => 'ModelSEED::DB::BiochemistryCompartment',
            map_from  => 'biochemistry',
            map_to    => 'compartment',
            type      => 'many to many',
        },

        compounds => {
            map_class => 'ModelSEED::DB::BiochemistryCompound',
            map_from  => 'biochemistry',
            map_to    => 'compound',
            type      => 'many to many',
        },

        compoundsets => {
            map_class => 'ModelSEED::DB::BiochemistryCompoundset',
            map_from  => 'biochemistry',
            map_to    => 'compoundset',
            type      => 'many to many',
        },

        mappings => {
            class      => 'ModelSEED::DB::Mapping',
            column_map => { uuid => 'biochemistry_uuid' },
            type       => 'one to many',
        },

        models => {
            class      => 'ModelSEED::DB::Model',
            column_map => { uuid => 'biochemistry_uuid' },
            type       => 'one to many',
        },

        parents => {
            map_class => 'ModelSEED::DB::BiochemistryParent',
            map_from  => 'child',
            map_to    => 'parent',
            type      => 'many to many',
        },

        reactions => {
            map_class => 'ModelSEED::DB::BiochemistryReaction',
            map_from  => 'biochemistry',
            map_to    => 'reaction',
            type      => 'many to many',
        },

        reactionsets => {
            map_class => 'ModelSEED::DB::BiochemistryReactionset',
            map_from  => 'biochemistry',
            map_to    => 'reactionset',
            type      => 'many to many',
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


1;
