########################################################################
# ModelSEED::MS::ReactionCue - This is the moose object corresponding to the ReactionCue object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-05T03:44:17
########################################################################
use strict;
use ModelSEED::MS::DB::ReactionCue;
package ModelSEED::MS::ReactionCue;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::ReactionCue';
# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
