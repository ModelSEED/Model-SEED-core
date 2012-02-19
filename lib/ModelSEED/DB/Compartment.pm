package ModelSEED::DB::Compartment;
use strict;
use Data::UUID;
use base qw(ModelSEED::DB::DB::Object::AutoBase2);
use ModelSEED::ApiHelpers;

sub serialize {
    my ($self, $args, $ctx) = @_;
    my $hash = {};
    ModelSEED::ApiHelpers::serializeAttributes($self,
        [$self->meta->columns], $hash);
    return $hash;
}
    

__PACKAGE__->meta->setup(
    table   => 'compartments',

    columns => [
        uuid    => { type => 'character', length => 36, not_null => 1 },
        modDate => { type => 'datetime' },
        locked  => { type => 'integer' },
        id      => { type => 'varchar', length => 2, not_null => 1 },
        name    => { type => 'varchar', default => '\'\'', length => 255 },
    ],

    primary_key_columns => [ 'uuid' ],

    relationships => [
        biochemistries => {
            map_class => 'ModelSEED::DB::BiochemistryCompartment',
            map_from  => 'compartment',
            map_to    => 'biochemistry',
            type      => 'many to many',
        },

        models => {
            map_class => 'ModelSEED::DB::ModelCompartment',
            map_from  => 'compartment',
            map_to    => 'model',
            type      => 'many to many',
        },

        reaction_rule_transports => {
            class      => 'ModelSEED::DB::ReactionRuleTransport',
            column_map => { uuid => 'compartment_uuid' },
            type       => 'one to many',
        },

        reaction_rules => {
            class      => 'ModelSEED::DB::ReactionRule',
            column_map => { uuid => 'compartment_uuid' },
            type       => 'one to many',
        },

        reactions => {
            class      => 'ModelSEED::DB::Reaction',
            column_map => { uuid => 'compartment_uuid' },
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


1;

