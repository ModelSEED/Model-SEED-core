########################################################################
# ModelSEED::MS::FBAPhenotypeSimultationResult - This is the moose object corresponding to the FBAPhenotypeSimultationResult object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-06-29T06:00:13
########################################################################
use strict;
use ModelSEED::MS::DB::FBAPhenotypeSimultationResult;
package ModelSEED::MS::FBAPhenotypeSimultationResult;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::FBAPhenotypeSimultationResult';
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
