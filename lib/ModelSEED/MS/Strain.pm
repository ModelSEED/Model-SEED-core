########################################################################
# ModelSEED::MS::Strain - This is the moose object corresponding to the Strain object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-01T08:09:02
########################################################################
use strict;
use ModelSEED::MS::DB::Strain;
package ModelSEED::MS::Strain;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::Strain';
# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
