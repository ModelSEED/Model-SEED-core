########################################################################
# ModelSEED::MS::Reagent - This is the moose object corresponding to the Reagent object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-20T05:05:02
########################################################################
use strict;
use namespace::autoclean;
use ModelSEED::MS::DB::Reagent;
package ModelSEED::MS::Reagent;
use Moose;
extends 'ModelSEED::MS::DB::Reagent';
# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
