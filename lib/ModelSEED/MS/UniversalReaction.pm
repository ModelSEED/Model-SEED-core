########################################################################
# ModelSEED::MS::UniversalReaction - This is the moose object corresponding to the UniversalReaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-28T22:56:11
########################################################################
use strict;
use ModelSEED::MS::DB::UniversalReaction;
package ModelSEED::MS::UniversalReaction;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::UniversalReaction';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has reactionID => ( is => 'rw', isa => 'Str',printOrder => '1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildreactionID' );
has reactionName => ( is => 'rw', isa => 'Str',printOrder => '2', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildreactionName' );
has reactionDefinition => ( is => 'rw', isa => 'Str',printOrder => '3', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildreactionDefinition' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildreactionID {
	my ($self) = @_;
	return $self->reactioninstance()->id();
}
sub _buildreactionName {
	my ($self) = @_;
	return $self->reactioninstance()->reaction()->name();
}
sub _buildreactionDefinition {
	my ($self) = @_;
	return $self->reactioninstance()->definition();
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************


__PACKAGE__->meta->make_immutable;
1;
