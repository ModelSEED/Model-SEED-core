########################################################################
# ModelSEED::MS::ModelReaction - This is the moose object corresponding to the ModelReaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-15T22:32:28
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject
use ModelSEED::MS::Model
use ModelSEED::MS::ModelReactionRawGPR
use ModelSEED::MS::ModelReactionTransports
use ModelSEED::MS::Reaction
use ModelSEED::MS::ModelCompartment
package ModelSEED::MS::ModelReaction
extends ModelSEED::MS::BaseObject


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Model',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has model_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has reaction_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has direction => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '=' );
has protons => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has model_compartment_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1 );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid');


# SUBOBJECTS:
has gpr => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ModelReactionRawGPR]', type => 'encompassed', metaclass => 'Typed');
has transports => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ModelReactionTransports]', type => 'encompassed', metaclass => 'Typed');


# LINKS:
has reaction => (is => 'rw',lazy => 1,builder => '_buildreaction',isa => 'ModelSEED::MS::Reaction',weak_ref => 1);
has modelcompartment => (is => 'rw',lazy => 1,builder => '_buildmodelcompartment',isa => 'ModelSEED::MS::ModelCompartment',weak_ref => 1);


# BUILDERS:
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now()->datetime(); }
sub _buildreaction {
	my ($self) = ;
	return $self->getLinkedObject('Biochemistry','Reaction','uuid',$self->reaction_uuid());
}
sub _buildmodelcompartment {
	my ($self) = ;
	return $self->getLinkedObject('Model','ModelCompartment','uuid',$self->model_compartment_uuid());
}


# CONSTANTS:
sub _type { return 'ModelReaction'; }


# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
