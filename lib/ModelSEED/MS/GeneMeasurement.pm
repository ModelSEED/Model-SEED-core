########################################################################
# ModelSEED::MS::GeneMeasurement - This is the moose object corresponding to the GeneMeasurement object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-01T08:09:02
########################################################################
use strict;
use ModelSEED::MS::DB::GeneMeasurement;
package ModelSEED::MS::GeneMeasurement;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::GeneMeasurement';
# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
