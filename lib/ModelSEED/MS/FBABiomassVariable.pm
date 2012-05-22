########################################################################
# ModelSEED::MS::FBABiomassVariable - This is the moose object corresponding to the FBABiomassVariable object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-05-19T23:15:32
########################################################################
use strict;
use ModelSEED::MS::DB::FBABiomassVariable;
package ModelSEED::MS::FBABiomassVariable;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::FBABiomassVariable';
# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
