########################################################################
# ModelSEED::MS::GapfillingSolution - This is the moose object corresponding to the GapfillingSolution object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-05-25T05:08:47
########################################################################
use strict;
use ModelSEED::MS::DB::GapfillingSolution;
package ModelSEED::MS::GapfillingSolution;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::GapfillingSolution';
# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
