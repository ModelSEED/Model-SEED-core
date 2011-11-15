package ModelSEED::MediaCompound;

use Moose;
use Data::UUID;
use ModelSEED::Role::DBObject;

with ('ModelSEED::Role::DBObject',
      'ModelSEED::Role::Relationship' => {
        role_type => 'one to one',
        object_type => 'ModelSEED::Media',
        object_name => 'media',
      },
      'ModelSEED::Role::Relationship' => {
        role_type => 'one to one',
        object_type => 'ModelSEED::Compound',
        object_name => 'compound'
      },
);

has 'concentration' => ( is => 'rw', isa => 'Num' );
has 'minFlux' => ( is => 'rw', isa => 'Num' );
has 'maxFlux' => ( is => 'rw', isa => 'Num' );

1;
