########################################################################
# ModelSEED::MS::Constraint - This is the moose object corresponding to the Constraint object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-05-05T02:39:57
########################################################################
use strict;
use ModelSEED::MS::DB::Constraint;
package ModelSEED::MS::Constraint;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::Constraint';
# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
