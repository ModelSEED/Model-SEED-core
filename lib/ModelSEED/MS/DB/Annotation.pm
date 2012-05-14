########################################################################
# ModelSEED::MS::DB::Annotation - This is the moose object corresponding to the Annotation object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Annotation;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::Genome;
use ModelSEED::MS::LazyHolder::Feature;
use ModelSEED::MS::LazyHolder::SubsystemState;
extends 'ModelSEED::MS::IndexedObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::Store', type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );
has name => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has mapping_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has genomes => (is => 'bare', coerce => 1, handles => { genomes => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::Genome::Lazy', type => 'child(Genome)', metaclass => 'Typed');
has features => (is => 'bare', coerce => 1, handles => { features => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::Feature::Lazy', type => 'child(Feature)', metaclass => 'Typed');
has subsystemStates => (is => 'bare', coerce => 1, handles => { subsystemStates => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::SubsystemState::Lazy', type => 'child(SubsystemState)', metaclass => 'Typed');


# LINKS:
has mapping => (is => 'rw',lazy => 1,builder => '_buildmapping',isa => 'ModelSEED::MS::Mapping', type => 'link(ModelSEED::Store,Mapping,uuid,mapping_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }
sub _buildmapping {
	my ($self) = @_;
	return $self->getLinkedObject('ModelSEED::Store','Mapping','uuid',$self->mapping_uuid());
}


# CONSTANTS:
sub _type { return 'Annotation'; }
sub _typeToFunction {
	return {
		Genome => 'genomes',
		SubsystemState => 'subsystemStates',
		Feature => 'features',
	};
}


__PACKAGE__->meta->make_immutable;
1;
