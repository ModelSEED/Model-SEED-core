########################################################################
# ModelSEED::MS::InstanceTransports - This is the moose object corresponding to the InstanceTransports object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-19T08:21:34
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::DB::InstanceTransports;
package ModelSEED::MS::InstanceTransports;
extends ModelSEED::MS::DB::InstanceTransports;
# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
