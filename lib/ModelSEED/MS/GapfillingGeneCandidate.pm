########################################################################
# ModelSEED::MS::GapfillingGeneCandidate - This is the moose object corresponding to the GapfillingGeneCandidate object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-05-21T20:27:15
########################################################################
use strict;
use ModelSEED::MS::DB::GapfillingGeneCandidate;
package ModelSEED::MS::GapfillingGeneCandidate;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::GapfillingGeneCandidate';
# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
