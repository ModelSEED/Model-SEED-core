########################################################################
# ModelSEED::MS::ReactionSet - This is the moose object corresponding to the ReactionSet object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use ModelSEED::MS::DB::ReactionSet;
package ModelSEED::MS::ReactionSet;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::ReactionSet';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************


#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
=head3 modelCoverage
Definition:
	fraction = ModelSEED::MS::ReactionSet->modelCoverage({
		model => ModelSEED::MS::Model(REQ)
	});
Description:
	Calculates the fraction of the reaction set covered by the model
=cut
sub modelCoverage {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["model"],{});
	#TODO
	return 1;
}
=head3 containsReaction
Definition:
	fraction = ModelSEED::MS::ReactionSet->containsReaction({
		model => ModelSEED::MS::Model(REQ)
	});
Description:
	Returns "1" if the reaction set contains the specified reaction
=cut
sub containsReaction {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["reaction"],{});
	#TODO
	return 1;
}

__PACKAGE__->meta->make_immutable;
1;
