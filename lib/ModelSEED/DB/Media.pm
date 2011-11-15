package ModelSEED::DB::Media;

use strict;

use base qw(ModelSEED::DB::DB::Object::AutoBase2);

__PACKAGE__->meta->setup(
    table   => 'media',

    columns => [
        uuid    => { type => 'character', length => 36, not_null => 1 },
        modDate => { type => 'datetime' },
        id      => { type => 'varchar', length => 32 },
        name    => { type => 'varchar', length => 255 },
        type    => { type => 'character', length => 1 },
    ],

    primary_key_columns => [ 'uuid' ],

    relationships => [
#        biochemistry => {
#            type => 'many to many', 
#        },
        
        genome => {
            class      => 'ModelSEED::DB::Genome',
            column_map => { uuid => 'media' },
            type       => 'one to many',
        },

        media_compound => {
            class      => 'ModelSEED::DB::MediaCompound',
            column_map => { uuid => 'media' },
            type       => 'one to many',
        },

        modelfba => {
            class      => 'ModelSEED::DB::Modelfba',
            column_map => { uuid => 'media' },
            type       => 'one to many',
        },
    ],
);

1;

