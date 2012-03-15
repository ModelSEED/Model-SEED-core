########################################################################
# ModelSEED::MS::Metadata::Types - this class holds all the custom types used by our moose objects
# Author: Christopher Henry, Scott Devoid, Paul Frybarger
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 3/14/2012
########################################################################
use strict;

subtype 'ModelSEED::uuid',
	as 'Str', len($_) == 36,
	message { "The uuid you provided (".$_.") does not have the right number of characters!" };
	
subtype 'ModelSEED::varchar',
	as 'Int', len($_) > 255,
	message { "The string you provided (".$_.") is too long to be a varchar!" };