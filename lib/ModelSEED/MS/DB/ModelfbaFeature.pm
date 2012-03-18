########################################################################
# ModelSEED::MS::ModelfbaFeature - This is the moose object corresponding to the ModelfbaFeature object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-15T22:32:28
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject
use ModelSEED::MS::Modelfba
use ModelSEED::MS::Feature
package ModelSEED::MS::ModelfbaFeature
extends ModelSEED::MS::BaseObject


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Modelfba',weak_ref => 1);


# ATTRIBUTES:
has modelfba_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has feature_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has growthFraction => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has essential => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed' );
has class => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has activity => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has ko => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );




# LINKS:
has feature => (is => 'rw',lazy => 1,builder => '_buildfeature',isa => 'ModelSEED::MS::Feature',weak_ref => 1);


# BUILDERS:
sub _buildfeature {
	my ($self) = ;
	return $self->getLinkedObject('Annotation','Feature','uuid',$self->feature_uuid());
}


# CONSTANTS:
sub _type { return 'ModelfbaFeature'; }


# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
