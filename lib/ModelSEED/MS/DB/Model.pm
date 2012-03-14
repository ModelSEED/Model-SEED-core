########################################################################
# ModelSEED::MS::Model - This is the moose object corresponding to the Model object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-14T07:56:20
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::IndexedObject
use ModelSEED::MS::ModelAlias
use ModelSEED::MS::Biomass
use ModelSEED::MS::ModelCompartment
use ModelSEED::MS::ModelCompound
use ModelSEED::MS::ModelReaction
use ModelSEED::MS::Biochemistry
use ModelSEED::MS::Mapping
use ModelSEED::MS::Annotation
package ModelSEED::MS::Model
extends ModelSEED::MS::IndexedObject


# PARENT:
has parent => (is => 'rw',required => 1,isa => 'ModelSEED::MS::ObjectManager',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'Str', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Int', default => '0' );
has public => ( is => 'rw', isa => 'Int', default => '0' );
has id => ( is => 'rw', isa => 'Str', required => 1 );
has name => ( is => 'rw', isa => 'Str', default => '' );
has version => ( is => 'rw', isa => 'Int', default => '0' );
has type => ( is => 'rw', isa => 'Str', default => 'Singlegenome' );
has status => ( is => 'rw', isa => 'Str' );
has reactions => ( is => 'rw', isa => 'Int' );
has compounds => ( is => 'rw', isa => 'Int' );
has annotations => ( is => 'rw', isa => 'Int' );
has growth => ( is => 'rw', isa => 'Num' );
has current => ( is => 'rw', isa => 'Int', default => '1' );
has mapping_uuid => ( is => 'rw', isa => 'Str' );
has biochemistry_uuid => ( is => 'rw', isa => 'Str', required => 1 );
has annotation_uuid => ( is => 'rw', isa => 'Str' );


# SUBOBJECTS:
has  => (is => 'rw',default => sub{return [];},isa => 'HashRef[ArrayRef]');
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Biomass]');
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ModelCompartment]');
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ModelCompound]');
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ModelReaction]');


# LINKS:
has biochemistry => (is => 'rw',lazy => 1,builder => '_buildbiochemistry',isa => 'ModelSEED::MS::Biochemistry',weak_ref => 1);
has mapping => (is => 'rw',lazy => 1,builder => '_buildmapping',isa => 'ModelSEED::MS::Mapping',weak_ref => 1);
has annotation => (is => 'rw',lazy => 1,builder => '_buildannotation',isa => 'ModelSEED::MS::Annotation',weak_ref => 1);


# BUILDERS:
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now()->datetime(); }
sub _buildbiochemistry {
	my ($self) = ;
	return $self->getLinkedObject('ObjectManager','Biochemistry','uuid',$self->biochemistry_uuid());
}
sub _buildmapping {
	my ($self) = ;
	return $self->getLinkedObject('ObjectManager','Mapping','uuid',$self->mapping_uuid());
}
sub _buildannotation {
	my ($self) = ;
	return $self->getLinkedObject('ObjectManager','Annotation','uuid',$self->annotation_uuid());
}


# CONSTANTS:
sub _type { return 'Model'; }


# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
