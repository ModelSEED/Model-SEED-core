########################################################################
# ModelSEED::MS::SolutionVariable - This is the moose object corresponding to the SolutionVariable object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-05-16T20:55:14
########################################################################
use strict;
use ModelSEED::MS::DB::SolutionVariable;
package ModelSEED::MS::SolutionVariable;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::SolutionVariable';
# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
