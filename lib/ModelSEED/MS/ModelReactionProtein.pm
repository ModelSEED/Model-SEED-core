########################################################################
# ModelSEED::MS::ModelReactionProtein - This is the moose object corresponding to the ModelReactionProtein object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-05-21T02:47:43
########################################################################
use strict;
use ModelSEED::MS::DB::ModelReactionProtein;
package ModelSEED::MS::ModelReactionProtein;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::ModelReactionProtein';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has gprString => ( is => 'rw', isa => 'Str',printOrder => '0', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildgprString' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildgprString {
	my ($self) = @_;
	if (@{$self->modelReactionProteinSubunits()} == 0) {
		if (length($self->note()) > 0) {
			return $self->note();
		}
		return "Unknown";
	}
	my $gpr = "";
	foreach my $subunit (@{$self->modelReactionProteinSubunits()}) {
		if (length($gpr) > 0) {
			$gpr .= " and ";	
		}
		$gpr .= $subunit->gprString();
	}
	if (@{$self->modelReactionProteinSubunits()} > 1) {
		$gpr = "(".$gpr.")";	
	}
	return $gpr;
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************


__PACKAGE__->meta->make_immutable;
1;
