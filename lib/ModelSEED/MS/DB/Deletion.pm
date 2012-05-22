########################################################################
# ModelSEED::MS::DB::Deletion - This is the moose object corresponding to the Deletion object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::Deletion;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Genome', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has start => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed' );
has stop => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# LINKS:


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }


# CONSTANTS:
sub _type { return 'Deletion'; }

my $attributes = ['uuid', 'start', 'stop'];
sub _attributes {
	return $attributes;
}

my $subobjects = [];
sub _subobjects {
	return $subobjects;
}


__PACKAGE__->meta->make_immutable;
1;
