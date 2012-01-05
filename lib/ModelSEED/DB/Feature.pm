package ModelSEED::DB::Feature;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'features',

    columns => [
        uuid        => { type => 'character', length => 36, not_null => 1 },
        modDate     => { type => 'datetime' },
        locked      => { type => 'integer' },
        id          => { type => 'varchar', length => 32 },
        cksum       => { type => 'varchar', length => 255 },
        genome_uuid => { type => 'character', length => 36, not_null => 1 },
        start       => { type => 'integer' },
        stop        => { type => 'integer' },
    ],

    primary_key_columns => [ 'uuid' ],

    foreign_keys => [
        genome => {
            class       => 'ModelSEED::DB::Genome',
            key_columns => { genome_uuid => 'uuid' },
        },
    ],

    relationships => [
        annotation_features => {
            class      => 'ModelSEED::DB::AnnotationFeature',
            column_map => { uuid => 'feature_uuid' },
            type       => 'one to many',
        },

        modelfbas => {
            map_class => 'ModelSEED::DB::ModelessFeature',
            map_from  => 'feature',
            map_to    => 'modelfba',
            type      => 'many to many',
        },

        roles => {
            class      => 'ModelSEED::DB::Role',
            column_map => { uuid => 'feature_uuid' },
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

