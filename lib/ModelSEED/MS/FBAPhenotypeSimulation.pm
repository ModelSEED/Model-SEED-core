########################################################################
# ModelSEED::MS::FBAPhenotypeSimulation - This is the moose object corresponding to the FBAPhenotypeSimulation object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-06-29T06:00:13
########################################################################
use strict;
use ModelSEED::MS::DB::FBAPhenotypeSimulation;
package ModelSEED::MS::FBAPhenotypeSimulation;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::FBAPhenotypeSimulation';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has knockouts => ( is => 'rw', isa => 'Str',printOrder => '3', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildknockouts' );
has mediaID => ( is => 'rw', isa => 'Str',printOrder => '1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildmediaID' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildknockouts {
	my ($self) = @_;
	my $geneKO = join(", ",@{$self->geneKO()});
	my $rxnKO = join(", ",@{$self->reactionKO()});
	if (length($geneKO) > 0 && length($rxnKO) > 0) {
		return $geneKO.", ".$rxnKO;
	}
	return $geneKO.$rxnKO;
}
sub _buildmediaID {
	my ($self) = @_;
	return $self->media()->id();
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************

__PACKAGE__->meta->make_immutable;
1;
