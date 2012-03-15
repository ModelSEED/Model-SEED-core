########################################################################
# ModelSEED::MS::RolesetRole - This is the moose object corresponding to the RolesetRole object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-15T16:44:01
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject
use ModelSEED::MS::
package ModelSEED::MS::RolesetRole
extends ModelSEED::MS::BaseObject


# PARENT:
has parent => (is => 'rw',required => 1,isa => 'ModelSEED::MS::',weak_ref => 1);


# ATTRIBUTES:


# BUILDERS:


# CONSTANTS:
sub _type { return 'RolesetRole'; }


# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
