package ModelSEED::DB::Complex;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'complexes',

    columns => [
        uuid       => { type => 'character', length => 36, not_null => 1 },
        modDate    => { type => 'datetime' },
        locked     => { type => 'integer' },
        id         => { type => 'varchar', length => 32 },
        name       => { type => 'varchar', length => 255 },
        searchname => { type => 'varchar', length => 255 },
    ],

    primary_key_columns => [ 'uuid' ],

    relationships => [
        mappings => {
            map_class => 'ModelSEED::DB::MappingComplex',
            map_from  => 'complex',
            map_to    => 'mapping',
            type      => 'many to many',
        },

        reaction_rule_transports => {
            class      => 'ModelSEED::DB::ReactionRuleTransport',
            column_map => { uuid => 'complex_uuid' },
            type       => 'one to many',
        },

        reaction_rules => {
            class      => 'ModelSEED::DB::ReactionRule',
            column_map => { uuid => 'complex_uuid' },
            type       => 'one to many',
        },

        roles => {
            map_class => 'ModelSEED::DB::ComplexRole',
            map_from  => 'complex',
            map_to    => 'role',
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

