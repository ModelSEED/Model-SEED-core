########################################################################
# ModelSEED::MS::Metadata::Types - this class holds all the custom types used by our moose objects
# Author: Christopher Henry, Scott Devoid, Paul Frybarger
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 3/14/2012
########################################################################
use strict;
use Moose::Util::TypeConstraints;

$ModelSEED::MS::Metadata::Types::uuidRegex = qr/[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}/;

subtype 'ModelSEED::uuid',
	as 'Str';
#    where { $_ =~ $ModelSEED::MS::Metadata::Types::uuidRegex },
#	message { "The string you provided ($_) is not a vaild UUID!" };

subtype 'ModelSEED::varchar',
	as 'Str', where { !defined($_) || length($_) < 256 },
	message { "The string you provided ($_) is too long to be a varchar!" };
