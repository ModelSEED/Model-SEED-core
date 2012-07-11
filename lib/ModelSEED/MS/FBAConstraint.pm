########################################################################
# ModelSEED::MS::FBAConstraint - This is the moose object corresponding to the FBAConstraint object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-06-01T03:14:10
########################################################################
use strict;
use ModelSEED::MS::DB::FBAConstraint;
package ModelSEED::MS::FBAConstraint;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::FBAConstraint';
# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
