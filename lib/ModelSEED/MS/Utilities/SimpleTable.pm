########################################################################
# ModelSEED::MS::Utilities::SimpleTable - This is a simple utility object 
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-15T16:44:01
########################################################################
use strict;
use namespace::autoclean;
package ModelSEED::MS::Utilities::SimpleTable;
use Moose;

# ATTRIBUTES:
has data => ( is => 'rw', isa => 'HashRef', required => 1);
has headingHash => ( is => 'rw', isa => 'HashRef', lazy => 1, builder => '_buildheadingHash' );

# BUILDERS:
sub _buildheadingHash {
	my ($self) = @_;
	my $hash;
	for (my $i=0; $i < @{$self->data()->{headings}}; $i++) {
		$hash->{$self->data()->{headings}->[$i]} = $i;
	}
	return $hash;
}

# CONSTANTS:


# FUNCTIONS:


__PACKAGE__->meta->make_immutable;
