########################################################################
# ModelSEED::MS::FBAMetaboliteProductionResult - This is the moose object corresponding to the FBAMetaboliteProductionResult object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-06-29T06:00:13
########################################################################
use strict;
use ModelSEED::MS::DB::FBAMetaboliteProductionResult;
package ModelSEED::MS::FBAMetaboliteProductionResult;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::FBAMetaboliteProductionResult';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has compoundID => ( is => 'rw', isa => 'Str',printOrder => '1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildcompoundID');
has compoundName => ( is => 'rw', isa => 'Str',printOrder => '2', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildcompoundName');

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildcompoundID {
	my ($self) = @_;
	return $self->modelCompound()->id();
}
sub _buildcompoundName {
	my ($self) = @_;
	return $self->modelCompound()->name();
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************


#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************


__PACKAGE__->meta->make_immutable;
1;
