########################################################################
# ModelSEED::MS::FBADeletionResult - This is the moose object corresponding to the FBADeletionResult object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-06-29T06:00:13
########################################################################
use strict;
use ModelSEED::MS::DB::FBADeletionResult;
package ModelSEED::MS::FBADeletionResult;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::FBADeletionResult';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has geneKnockouts => ( is => 'rw', isa => 'Str',printOrder => '0', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildgeneKnockouts');

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildgeneKnockouts {
	my ($self) = @_;
	my $string = "";
	my $kos = $self->genekos();
	for (my $i=0; $i < @{$kos}; $i++) {
		if ($i > 0) {
			$string .= ", ";
		}
		$string .= $kos->[$i]->id();
	}
	return $string;
}


#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************


__PACKAGE__->meta->make_immutable;
1;
