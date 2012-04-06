########################################################################
# ModelSEED::MS::RolesetRole - This is the moose object corresponding to the RolesetRole object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-05T20:28:05
########################################################################
use strict;
use ModelSEED::MS::DB::RolesetRole;
package ModelSEED::MS::RolesetRole;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::RolesetRole';
# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
