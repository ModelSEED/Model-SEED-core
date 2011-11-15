package ModelSEED::MediaCompound;

use Moose;
use Data::UUID;
use ModelSEED::Role::DBObject;

with 'ModelSEED::Role::DBObject';

# has_one 'media' => ( table => 'media', )
# has_one 'compound' => ( table => 'compound' )
# ... results in
# has media => ( is => 'rw', isa => 'ModelSEED::Media', required => 1)

has 'media' => (is => 'ro', isa => 'ModelSEED::Media', required => 1);
has 'compound' => (is => 'ro', isa => 'ModelSEED::Compound', required => 1);
has 'concentration' => ( is => 'rw', isa => 'Num' );
has 'minFlux' => ( is => 'rw', isa => 'Num' );
has 'maxFlux' => ( is => 'rw', isa => 'Num' );

1;
