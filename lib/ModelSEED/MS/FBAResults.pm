########################################################################
# ModelSEED::MS::FBAResults - This is the moose object corresponding to the FBAResults object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-28T22:56:11
########################################################################
use strict;
use ModelSEED::MS::DB::FBAResults;
package ModelSEED::MS::FBAResults;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::FBAResults';
# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
