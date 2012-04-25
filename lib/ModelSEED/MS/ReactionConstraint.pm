########################################################################
# ModelSEED::MS::ReactionConstraint - This is the moose object corresponding to the ReactionConstraint object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-24T02:58:24
########################################################################
use strict;
use ModelSEED::MS::DB::ReactionConstraint;
package ModelSEED::MS::ReactionConstraint;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::ReactionConstraint';
# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
