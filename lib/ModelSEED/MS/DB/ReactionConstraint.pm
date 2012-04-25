########################################################################
# ModelSEED::MS::DB::ReactionConstraint - This is the moose object corresponding to the ReactionConstraint object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-24T02:58:24
########################################################################
use strict;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::ReactionConstraint;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Modelfba', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has modelreaction_uuid => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has minUptake => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0' );
has maxUptake => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0' );




# LINKS:


# BUILDERS:


# CONSTANTS:
sub _type { return 'ReactionConstraint'; }


__PACKAGE__->meta->make_immutable;
1;
