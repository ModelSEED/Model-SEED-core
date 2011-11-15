package ModelSEED::Role::ModDate;

use Moose::Role;
use DateTime;

has modDate => (
    is => 'rw', isa => 'DateTime',
    lazy => 1, builder => '_buildModDate'
);

sub _buildModDate {
   return DateTime->now; 
}

1;
