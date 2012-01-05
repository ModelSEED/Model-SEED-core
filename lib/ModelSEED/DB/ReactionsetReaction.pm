package ModelSEED::DB::ReactionsetReaction;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'reactionset_reactions',

    columns => [
        reactionset_uuid => { type => 'character', length => 36, not_null => 1 },
        reaction_uuid    => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'reactionset_uuid', 'reaction_uuid' ],

    foreign_keys => [
        reaction => {
            class       => 'ModelSEED::DB::Reaction',
            key_columns => { reaction_uuid => 'uuid' },
        },

        reactionset => {
            class       => 'ModelSEED::DB::Reactionset',
            key_columns => { reactionset_uuid => 'uuid' },
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

