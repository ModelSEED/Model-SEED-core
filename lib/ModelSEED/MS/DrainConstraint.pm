########################################################################
# ModelSEED::MS::DrainConstraint - This is the moose object corresponding to the DrainConstraint object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-24T02:58:25
########################################################################
use strict;
use ModelSEED::MS::DB::DrainConstraint;
package ModelSEED::MS::DrainConstraint;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::DrainConstraint';
# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
