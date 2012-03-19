########################################################################
# ModelSEED::MS::DB::ComplexReactionRule - This is the moose object corresponding to the ComplexReactionRule object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-19T08:21:34
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::;
package ModelSEED::MS::DB::ComplexReactionRule;
extends ModelSEED::MS::BaseObject;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::',weak_ref => 1);


# ATTRIBUTES:




# BUILDERS:


# CONSTANTS:
sub _type { return 'ComplexReactionRule'; }


__PACKAGE__->meta->make_immutable;
1;
