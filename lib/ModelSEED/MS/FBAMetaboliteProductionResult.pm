########################################################################
# ModelSEED::MS::FBAMetaboliteProductionResult - This is the moose object corresponding to the FBAMetaboliteProductionResult object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-06-29T06:00:13
########################################################################
use strict;
use ModelSEED::MS::DB::FBAMetaboliteProductionResult;
package ModelSEED::MS::FBAMetaboliteProductionResult;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::FBAMetaboliteProductionResult';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************


#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************



#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************


__PACKAGE__->meta->make_immutable;
1;
