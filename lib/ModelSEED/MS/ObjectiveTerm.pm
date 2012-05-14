########################################################################
# ModelSEED::MS::ObjectiveTerm - This is the moose object corresponding to the ObjectiveTerm object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-05-08T19:43:45
########################################################################
use strict;
use ModelSEED::MS::DB::ObjectiveTerm;
package ModelSEED::MS::ObjectiveTerm;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::ObjectiveTerm';
# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
