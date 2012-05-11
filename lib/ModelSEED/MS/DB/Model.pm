########################################################################
# ModelSEED::MS::DB::Model - This is the moose object corresponding to the Model object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use ModelSEED::MS::Biomass;
use ModelSEED::MS::ModelCompartment;
use ModelSEED::MS::ModelCompound;
use ModelSEED::MS::ModelReaction;
use ModelSEED::MS::IndexedObject;
package ModelSEED::MS::DB::Model;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::IndexedObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::Store', type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );
has public => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );
has id => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', required => 1 );
has name => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '' );
has version => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );
has type => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => 'Singlegenome' );
has status => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has growth => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has current => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '1' );
has mapping_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );
has biochemistry_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has annotation_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has biomasses => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Biomass]', type => 'child(Biomass)', metaclass => 'Typed');
has modelcompartments => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ModelCompartment]', type => 'child(ModelCompartment)', metaclass => 'Typed');
has modelcompounds => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ModelCompound]', type => 'child(ModelCompound)', metaclass => 'Typed');
has modelreactions => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ModelReaction]', type => 'child(ModelReaction)', metaclass => 'Typed');


# LINKS:
has biochemistry => (is => 'rw',lazy => 1,builder => '_buildbiochemistry',isa => 'ModelSEED::MS::Biochemistry', type => 'link(ModelSEED::Store,Biochemistry,uuid,biochemistry_uuid)', metaclass => 'Typed',weak_ref => 1);
has mapping => (is => 'rw',lazy => 1,builder => '_buildmapping',isa => 'ModelSEED::MS::Mapping', type => 'link(ModelSEED::Store,Mapping,uuid,mapping_uuid)', metaclass => 'Typed',weak_ref => 1);
has annotation => (is => 'rw',lazy => 1,builder => '_buildannotation',isa => 'ModelSEED::MS::Annotation', type => 'link(ModelSEED::Store,Annotation,uuid,annotation_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }
sub _buildbiochemistry {
	my ($self) = @_;
	return $self->getLinkedObject('ModelSEED::Store','Biochemistry','uuid',$self->biochemistry_uuid());
}
sub _buildmapping {
	my ($self) = @_;
	return $self->getLinkedObject('ModelSEED::Store','Mapping','uuid',$self->mapping_uuid());
}
sub _buildannotation {
	my ($self) = @_;
	return $self->getLinkedObject('ModelSEED::Store','Annotation','uuid',$self->annotation_uuid());
}


# CONSTANTS:
sub _type { return 'Model'; }
sub _typeToFunction {
	return {
		Biomass => 'biomasses',
		ModelReaction => 'modelreactions',
		ModelCompound => 'modelcompounds',
		ModelCompartment => 'modelcompartments',
	};
}


__PACKAGE__->meta->make_immutable;
1;
