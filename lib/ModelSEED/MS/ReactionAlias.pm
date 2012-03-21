########################################################################
# ModelSEED::MS::ReactionAlias - This is the moose object corresponding to the ReactionAlias object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-21T23:35:48
########################################################################
use strict;
use namespace::autoclean;
use ModelSEED::MS::DB::ReactionAlias;
package ModelSEED::MS::ReactionAlias;
use Moose;
extends 'ModelSEED::MS::DB::ReactionAlias';
# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
