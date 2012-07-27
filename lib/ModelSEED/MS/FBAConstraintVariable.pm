########################################################################
# ModelSEED::MS::FBAConstraintVariable - This is the moose object corresponding to the FBAConstraintVariable object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-06-01T03:14:10
########################################################################
use strict;
use ModelSEED::MS::DB::FBAConstraintVariable;
package ModelSEED::MS::FBAConstraintVariable;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::FBAConstraintVariable';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has entity => ( is => 'rw', isa => 'Ref',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildentity' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildentity {
	my ($self) = @_;
	my $typeTranslation = {
		ModelCompound => "modelcompounds",
		ModelReaction => "modelreactions",
		Biomass => "biomasses"
	};
	if (defined($typeTranslation->{$self->entityType()})) {
		return $self->model()->getObject($typeTranslation->{$self->entityType()},$self->entity_uuid());
	}
	ModelSEED::utilities::ERROR("Unrecognized entity type:".$self->entityType());
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************


__PACKAGE__->meta->make_immutable;
1;
