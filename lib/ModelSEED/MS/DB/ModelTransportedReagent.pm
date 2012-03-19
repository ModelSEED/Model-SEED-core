########################################################################
# ModelSEED::MS::DB::ModelTransportedReagent - This is the moose object corresponding to the ModelTransportedReagent object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-19T19:49:19
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::;
package ModelSEED::MS::DB::ModelTransportedReagent;
extends ModelSEED::MS::BaseObject;


# PARENT:
#has parent => (is => 'rw',isa => 'ModelSEED::MS::',weak_ref => 1);


# ATTRIBUTES:




# BUILDERS:


# CONSTANTS:
sub _type { return 'ModelTransportedReagent'; }


__PACKAGE__->meta->make_immutable;
1;
