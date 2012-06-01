########################################################################
# ModelSEED::MS::DB::Model - This is the moose object corresponding to the Model object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Model;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::GapfillingFormulation;
use ModelSEED::MS::LazyHolder::Biomass;
use ModelSEED::MS::LazyHolder::ModelCompartment;
use ModelSEED::MS::LazyHolder::ModelCompound;
use ModelSEED::MS::LazyHolder::ModelReaction;
extends 'ModelSEED::MS::IndexedObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::Store', type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid', printOrder => '0' );
has defaultNameSpace => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => 'ModelSEED', printOrder => '3' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate', printOrder => '-1' );
has locked => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '-1' );
has public => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '-1' );
has id => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '1' );
has name => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '', printOrder => '2' );
has version => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '3' );
has type => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => 'Singlegenome', printOrder => '5' );
has status => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '7' );
has growth => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', printOrder => '6' );
has current => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '4' );
has mapping_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '8' );
has biochemistry_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '9' );
has annotation_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '10' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has gapfillingformulations => (is => 'bare', coerce => 1, handles => { gapfillingformulations => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::GapfillingFormulation::Lazy', type => 'child(GapfillingFormulation)', metaclass => 'Typed', printOrder => '4');
has biomasses => (is => 'bare', coerce => 1, handles => { biomasses => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::Biomass::Lazy', type => 'child(Biomass)', metaclass => 'Typed', printOrder => '0');
has modelcompartments => (is => 'bare', coerce => 1, handles => { modelcompartments => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::ModelCompartment::Lazy', type => 'child(ModelCompartment)', metaclass => 'Typed', printOrder => '1');
has modelcompounds => (is => 'bare', coerce => 1, handles => { modelcompounds => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::ModelCompound::Lazy', type => 'child(ModelCompound)', metaclass => 'Typed', printOrder => '2');
has modelreactions => (is => 'bare', coerce => 1, handles => { modelreactions => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::ModelReaction::Lazy', type => 'child(ModelReaction)', metaclass => 'Typed', printOrder => '3');


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
		GapfillingFormulation => 'gapfillingformulations',
	};
}


__PACKAGE__->meta->make_immutable;
1;
