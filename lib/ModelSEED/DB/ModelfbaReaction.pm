package ModelSEED::DB::ModelfbaReaction;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'modelfba_reactions',

    columns => [
        modelfba_uuid => { type => 'character', length => 36, not_null => 1 },
        reaction_uuid => { type => 'character', length => 36, not_null => 1 },
        min           => { type => 'scalar' },
        max           => { type => 'scalar' },
        class         => { type => 'character', length => 1 },
    ],

    primary_key_columns => [ 'modelfba_uuid', 'reaction_uuid' ],

    foreign_keys => [
        modelfba => {
            class       => 'ModelSEED::DB::Modelfba',
            key_columns => { modelfba_uuid => 'uuid' },
        },

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

