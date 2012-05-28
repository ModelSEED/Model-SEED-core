########################################################################
# ModelSEED::MS::FBAReactionVariable - This is the moose object corresponding to the FBAReactionVariable object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-28T22:56:11
########################################################################
use strict;
use ModelSEED::MS::DB::FBAReactionVariable;
package ModelSEED::MS::FBAReactionVariable;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::FBAReactionVariable';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has reactionID => ( is => 'rw', isa => 'Str',printOrder => '1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildreactionID');
has reactionName => ( is => 'rw', isa => 'Str',printOrder => '2', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildreactionName');

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildreactionID {
	my ($self) = @_;
	return $self->modelreaction()->reaction()->id();
}
sub _buildreactionName {
	my ($self) = @_;
	return $self->modelreaction()->reaction()->name();
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
