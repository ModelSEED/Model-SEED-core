########################################################################
# ModelSEED::MS::FeatureRole - This is the moose object corresponding to the FeatureRole object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-15T22:32:28
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject
use ModelSEED::MS::Feature
use ModelSEED::MS::Role
package ModelSEED::MS::FeatureRole
extends ModelSEED::MS::BaseObject


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Feature',weak_ref => 1);


# ATTRIBUTES:
has feature_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has role_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has compartment => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => 'unknown' );
has comment => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '' );
has delimiter => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '' );




# LINKS:
has role => (is => 'rw',lazy => 1,builder => '_buildrole',isa => 'ModelSEED::MS::Role',weak_ref => 1);


# BUILDERS:
sub _buildrole {
	my ($self) = ;
	return $self->getLinkedObject('Mapping','Role','uuid',$self->role_uuid());
}


# CONSTANTS:
sub _type { return 'FeatureRole'; }


# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
