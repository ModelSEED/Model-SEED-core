########################################################################
# ModelSEED::MS::ReactionSetReaction - This is the moose object corresponding to the ReactionSetReaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-05T20:28:05
########################################################################
use strict;
use ModelSEED::MS::DB::ReactionSetReaction;
package ModelSEED::MS::ReactionSetReaction;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::ReactionSetReaction';
# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
