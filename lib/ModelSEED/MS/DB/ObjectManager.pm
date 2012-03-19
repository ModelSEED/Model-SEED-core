########################################################################
# ModelSEED::MS::DB::ObjectManager - This is the moose object corresponding to the ObjectManager object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-19T08:21:34
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::IndexedObject;
use ModelSEED::MS::;
use ModelSEED::MS::User;
package ModelSEED::MS::DB::ObjectManager;
extends ModelSEED::MS::IndexedObject;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::',weak_ref => 1);


# ATTRIBUTES:
has user_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed' );




# LINKS:
has user => (is => 'rw',lazy => 1,builder => '_builduser',isa => 'ModelSEED::MS::User',weak_ref => 1);


# BUILDERS:
sub _builduser {
	my ($self) = ;
	return $self->getLinkedObject('self','User','uuid',$self->user_uuid());
}


# CONSTANTS:
sub _type { return 'ObjectManager'; }


__PACKAGE__->meta->make_immutable;
1;
