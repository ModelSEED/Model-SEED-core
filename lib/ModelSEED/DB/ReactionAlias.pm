package ModelSEED::DB::ReactionAlias;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'reaction_aliases',

    columns => [
        reaction_uuid => { type => 'character', length => 36, not_null => 1 },
        alias         => { type => 'varchar', length => 255, not_null => 1 },
        modDate       => { type => 'varchar', length => 45 },
        type          => { type => 'varchar', length => 32, not_null => 1 },
    ],

    primary_key_columns => [ 'type', 'alias' ],

    foreign_keys => [
        reaction => {
            class       => 'ModelSEED::DB::Reaction',
            key_columns => { reaction_uuid => 'uuid' },
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

