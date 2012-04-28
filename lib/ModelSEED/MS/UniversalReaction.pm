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
# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
