########################################################################
# ModelSEED::MS::DB::User - This is the moose object corresponding to the User object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::User;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::Store', type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid', printOrder => '0' );
has login => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );
has password => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );
has email => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '', printOrder => '0' );
has firstname => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '', printOrder => '0' );
has lastname => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '', printOrder => '0' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# LINKS:


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }


# CONSTANTS:
sub _type { return 'User'; }


__PACKAGE__->meta->make_immutable;
1;
