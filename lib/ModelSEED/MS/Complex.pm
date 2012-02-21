package ModelSEED::MS::Complex;
use Moose;
use namespace::autoclean;
use DateTime;
use Data::UUID;
use ModelSEED::MS::Complex;

# Basic attributes
has type => ( is => 'ro', isa => 'Str', default => 'Mapping');
has uuid => ( is => 'rw', isa => 'Str', builder => '_buildUUID');
has modDate => ( is => 'rw', isa => 'DateTime', builder => '_buildDate');
has locked => ( is => 'rw', isa => 'Bool', default => 0);
has public => ( is => 'rw', isa => 'Bool', default => 0);
# Relationships
has reaction_rules => ( is => 'rw', isa => 'ArrayRef');

sub _buildUUID { return Data::UUID->new()->create()->to_string(); }
sub _buildDate { return DateTime->now(); }
__PACKAGE__->meta->make_immutable;
1;
