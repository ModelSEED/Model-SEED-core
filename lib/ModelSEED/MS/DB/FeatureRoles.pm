########################################################################
# ModelSEED::MS::FeatureRoles - This is the moose object corresponding to the FeatureRoles object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-15T16:44:01
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject
use ModelSEED::MS::Feature
use ModelSEED::MS::Role
package ModelSEED::MS::FeatureRoles
extends ModelSEED::MS::BaseObject


# PARENT:
has parent => (is => 'rw',required => 1,isa => 'ModelSEED::MS::Feature',weak_ref => 1);


# ATTRIBUTES:
has annotation_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has feature_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has role_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has complete_string => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '' );


# LINKS:
has role => (is => 'rw',lazy => 1,builder => '_buildrole',isa => 'ModelSEED::MS::Role',weak_ref => 1);


# BUILDERS:
sub _buildrole {
	my ($self) = ;
	return $self->getLinkedObject('Mapping','Role','uuid',$self->role_uuid());
}


# CONSTANTS:
sub _type { return 'FeatureRoles'; }


# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
