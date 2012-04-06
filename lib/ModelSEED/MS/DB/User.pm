########################################################################
# ModelSEED::MS::DB::User - This is the moose object corresponding to the User object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-05T22:41:35
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
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has login => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );
has password => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );
has email => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '' );
has firstname => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '' );
has lastname => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# LINKS:


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }


# CONSTANTS:
sub _type { return 'User'; }


__PACKAGE__->meta->make_immutable;
1;
