########################################################################
# ModelSEED::MS::DB::User - This is the moose object corresponding to the User object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-29T05:19:03
########################################################################
use strict;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::User;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::ObjectManager', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has login => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );
has password => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );
has email => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '' );
has firstname => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '' );
has lastname => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '' );


# LINKS:


# BUILDERS:


# CONSTANTS:
sub _type { return 'User'; }


__PACKAGE__->meta->make_immutable;
1;
