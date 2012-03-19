########################################################################
# ModelSEED::MS::DB::ModelCompound - This is the moose object corresponding to the ModelCompound object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-19T08:21:34
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::Model;
use ModelSEED::MS::Compound;
use ModelSEED::MS::ModelCompartment;
package ModelSEED::MS::DB::ModelCompound;
extends ModelSEED::MS::BaseObject;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Model',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has model_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has compound_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has charge => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has formula => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '' );
has model_compartment_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1 );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid');


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


__PACKAGE__->meta->make_immutable;
1;
