package ModelSEED::DB::Genome;

use strict;
use Data::UUID;
use DateTime;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'genome',

    columns => [
        uuid       => { type => 'character', length => 36, not_null => 1 },
        modDate    => { type => 'datetime' },
        locked     => { type => 'integer' },
        public     => { type => 'integer' },
        id         => { type => 'varchar', length => 32 },
        name       => { type => 'varchar', length => 32 },
        source     => { type => 'varchar', length => 32 },
        type       => { type => 'varchar', length => 32 },
        taxonomy   => { type => 'varchar', length => 255 },
        cksum      => { type => 'varchar', length => 255 },
        size       => { type => 'integer' },
        genes      => { type => 'integer' },
        gc         => { type => 'scalar', length => 64 },
        cellwall   => { type => 'character', length => 1 },
        aerobicity => { type => 'character', length => 1 },
        media      => { type => 'character', length => 36, not_null => 1 },
    ],

    primary_key_columns => [ 'uuid' ],

    foreign_keys => [
        media_obj => {
            class       => 'ModelSEED::DB::Media',
            key_columns => { media => 'uuid' },
        },
    ],

    relationships => [
        annotation => {
            class      => 'ModelSEED::DB::Annotation',
            column_map => { uuid => 'genome' },
            type       => 'one to many',
        },

        feature => {
            class      => 'ModelSEED::DB::Feature',
            column_map => { uuid => 'genome' },
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

