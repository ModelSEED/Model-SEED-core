########################################################################
# ModelSEED::MS::FBACompoundVariable - This is the moose object corresponding to the FBACompoundVariable object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-28T22:56:11
########################################################################
use strict;
use ModelSEED::MS::DB::FBACompoundVariable;
package ModelSEED::MS::FBACompoundVariable;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::FBACompoundVariable';
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
	return $self->modelcompound()->compound()->id();
}
sub _buildcompoundName {
	my ($self) = @_;
	return $self->modelcompound()->compound()->name();
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************


#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
=head3 clearProblem
Definition:
	Output = ModelSEED::MS::Model->clearProblem();
	Output = {
		success => 0/1
	};
Description:
	Builds the FBA problem
=cut

__PACKAGE__->meta->make_immutable;
1;
