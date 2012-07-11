########################################################################
# ModelSEED::MS::SolutionVariable - This is the moose object corresponding to the SolutionVariable object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-05-16T20:55:14
########################################################################
use strict;
use ModelSEED::MS::DB::SolutionVariable;
package ModelSEED::MS::SolutionVariable;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::SolutionVariable';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has variableName => ( is => 'rw', isa => 'Str',printOrder => '0', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildvariableName' );
has variableType => ( is => 'rw', isa => 'Str',printOrder => '1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildvariableType' );


#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildvariableName {
	my ($self) = @_;
	return $self->variable()->name();
}
sub _buildvariableType {
	my ($self) = @_;
	return $self->variable()->type();
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************


__PACKAGE__->meta->make_immutable;
1;
