########################################################################
# ModelSEED::MS::ModelCompound - This is the moose object corresponding to the ModelCompound object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-14T07:56:20
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject
use ModelSEED::MS::Compound
use ModelSEED::MS::ModelCompartment
package ModelSEED::MS::ModelCompound
extends ModelSEED::MS::BaseObject


# PARENT:
has parent => (is => 'rw',required => 1,isa => 'ModelSEED::MS::Model',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'Str', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', lazy => 1, builder => '_buildmodDate' );
has model_uuid => ( is => 'rw', isa => 'Str', required => 1 );
has compound_uuid => ( is => 'rw', isa => 'Str', required => 1 );
has charge => ( is => 'rw', isa => 'Num' );
has formula => ( is => 'rw', isa => 'Str', default => '' );
has model_compartment_uuid => ( is => 'rw', isa => 'Str', required => 1 );


# LINKS:
has compound => (is => 'rw',lazy => 1,builder => '_buildcompound',isa => 'ModelSEED::MS::Compound',weak_ref => 1);
has modelcompartment => (is => 'rw',lazy => 1,builder => '_buildmodelcompartment',isa => 'ModelSEED::MS::ModelCompartment',weak_ref => 1);


# BUILDERS:
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now()->datetime(); }
sub _buildcompound {
	my ($self) = ;
	return $self->getLinkedObject('Biochemistry','Compound','uuid',$self->compound_uuid());
}
sub _buildmodelcompartment {
	my ($self) = ;
	return $self->getLinkedObject('Model','ModelCompartment','uuid',$self->model_compartment_uuid());
}


# CONSTANTS:
sub _type { return 'ModelCompound'; }


# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
