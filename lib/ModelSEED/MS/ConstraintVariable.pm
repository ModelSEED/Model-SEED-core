########################################################################
# ModelSEED::MS::ConstraintVariable - This is the moose object corresponding to the ConstraintVariable object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-05-05T02:39:58
########################################################################
use strict;
use ModelSEED::MS::DB::ConstraintVariable;
package ModelSEED::MS::ConstraintVariable;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::ConstraintVariable';
# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
