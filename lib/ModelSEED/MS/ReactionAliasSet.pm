########################################################################
# ModelSEED::MS::ReactionAliasSet - This is the moose object corresponding to the ReactionAliasSet object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use ModelSEED::MS::DB::ReactionAliasSet;
package ModelSEED::MS::ReactionAliasSet;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::ReactionAliasSet';
# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
