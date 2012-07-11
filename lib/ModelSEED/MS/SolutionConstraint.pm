########################################################################
# ModelSEED::MS::SolutionConstraint - This is the moose object corresponding to the SolutionConstraint object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-05-16T20:55:14
########################################################################
use strict;
use ModelSEED::MS::DB::SolutionConstraint;
package ModelSEED::MS::SolutionConstraint;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::SolutionConstraint';
# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
