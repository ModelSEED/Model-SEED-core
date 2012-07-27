########################################################################
# ModelSEED::MS::FBAPhenotypeSimultationResult - This is the moose object corresponding to the FBAPhenotypeSimultationResult object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-06-29T06:00:13
########################################################################
use strict;
use ModelSEED::MS::DB::FBAPhenotypeSimultationResult;
package ModelSEED::MS::FBAPhenotypeSimultationResult;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::FBAPhenotypeSimultationResult';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has mediaID => ( is => 'rw', isa => 'Str',printOrder => '0', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildmediaID' );
has knockouts => ( is => 'rw', isa => 'Str',printOrder => '1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildknockouts' );
has observedGrowthFraction => ( is => 'rw', isa => 'Str',printOrder => '2', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildobservedGrowth' );


#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildmediaID {
	my ($self) = @_;
	return $self->fbaPhenotypeSimulation()->media()->id();
}
sub _buildknockouts {
	my ($self) = @_;
	return $self->fbaPhenotypeSimulation()->knockouts();
}
sub _buildobservedGrowthFraction {
	my ($self) = @_;
	return $self->fbaPhenotypeSimulation()->observedGrowthFraction();
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************


__PACKAGE__->meta->make_immutable;
1;
