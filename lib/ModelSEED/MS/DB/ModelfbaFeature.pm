########################################################################
# ModelSEED::MS::ModelfbaFeature - This is the moose object corresponding to the ModelfbaFeature object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-14T07:56:20
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject
use ModelSEED::MS::Feature
package ModelSEED::MS::ModelfbaFeature
extends ModelSEED::MS::BaseObject


# PARENT:
has parent => (is => 'rw',required => 1,isa => 'ModelSEED::MS::Modelfba',weak_ref => 1);


# ATTRIBUTES:
has modelfba_uuid => ( is => 'rw', isa => 'Str', required => 1 );
has feature_uuid => ( is => 'rw', isa => 'Str', required => 1 );
has growthFraction => ( is => 'rw', isa => 'Num' );
has essential => ( is => 'rw', isa => 'Int' );
has class => ( is => 'rw', isa => 'Str' );
has activity => ( is => 'rw', isa => 'Num' );
has ko => ( is => 'rw', isa => 'Int', default => '0' );


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
