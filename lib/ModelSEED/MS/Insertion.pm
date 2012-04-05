########################################################################
# ModelSEED::MS::Insertion - This is the moose object corresponding to the Insertion object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-01T08:09:02
########################################################################
use strict;
use ModelSEED::MS::DB::Insertion;
package ModelSEED::MS::Insertion;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::Insertion';
# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
