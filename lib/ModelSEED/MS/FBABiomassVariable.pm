########################################################################
# ModelSEED::MS::FBABiomassVariable - This is the moose object corresponding to the FBABiomassVariable object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-05-19T23:15:32
########################################################################
use strict;
use ModelSEED::MS::DB::FBABiomassVariable;
package ModelSEED::MS::FBABiomassVariable;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::FBABiomassVariable';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has biomassName => ( is => 'rw', isa => 'Str',printOrder => '1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildbiomassName');

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildbiomassName {
	my ($self) = @_;
	return $self->biomass()->name();
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
