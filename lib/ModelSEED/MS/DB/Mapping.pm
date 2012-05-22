########################################################################
# ModelSEED::MS::DB::Mapping - This is the moose object corresponding to the Mapping object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Mapping;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::UniversalReaction;
use ModelSEED::MS::LazyHolder::BiomassTemplate;
use ModelSEED::MS::LazyHolder::Role;
use ModelSEED::MS::LazyHolder::RoleSet;
use ModelSEED::MS::LazyHolder::Complex;
use ModelSEED::MS::LazyHolder::RoleSetAliasSet;
use ModelSEED::MS::LazyHolder::RoleAliasSet;
use ModelSEED::MS::LazyHolder::ComplexAliasSet;
extends 'ModelSEED::MS::IndexedObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::Store', type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid', printOrder => '0' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate', printOrder => '-1' );
has locked => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '-1' );
has public => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '-1' );
has name => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '', printOrder => '1' );
has defaultNameSpace => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => 'SEED', printOrder => '2' );
has biochemistry_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '3' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has universalReactions => (is => 'bare', coerce => 1, handles => { universalReactions => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::UniversalReaction::Lazy', type => 'child(UniversalReaction)', metaclass => 'Typed', printOrder => '0');
has biomassTemplates => (is => 'bare', coerce => 1, handles => { biomassTemplates => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::BiomassTemplate::Lazy', type => 'child(BiomassTemplate)', metaclass => 'Typed', printOrder => '1');
has roles => (is => 'bare', coerce => 1, handles => { roles => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::Role::Lazy', type => 'child(Role)', metaclass => 'Typed', printOrder => '2');
has rolesets => (is => 'bare', coerce => 1, handles => { rolesets => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::RoleSet::Lazy', type => 'child(RoleSet)', metaclass => 'Typed', printOrder => '3');
has complexes => (is => 'bare', coerce => 1, handles => { complexes => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::Complex::Lazy', type => 'child(Complex)', metaclass => 'Typed', printOrder => '4');
has roleSetAliasSets => (is => 'bare', coerce => 1, handles => { roleSetAliasSets => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::RoleSetAliasSet::Lazy', type => 'child(RoleSetAliasSet)', metaclass => 'Typed');
has roleAliasSets => (is => 'bare', coerce => 1, handles => { roleAliasSets => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::RoleAliasSet::Lazy', type => 'child(RoleAliasSet)', metaclass => 'Typed');
has complexAliasSets => (is => 'bare', coerce => 1, handles => { complexAliasSets => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::ComplexAliasSet::Lazy', type => 'child(ComplexAliasSet)', metaclass => 'Typed');


# LINKS:
has biochemistry => (is => 'rw',lazy => 1,builder => '_buildbiochemistry',isa => 'ModelSEED::MS::Biochemistry', type => 'link(ModelSEED::Store,Biochemistry,uuid,biochemistry_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }
sub _buildbiochemistry {
	my ($self) = @_;
	return $self->getLinkedObject('ModelSEED::Store','Biochemistry','uuid',$self->biochemistry_uuid());
}


# CONSTANTS:
sub _type { return 'Mapping'; }
sub _typeToFunction {
	return {
		RoleSet => 'rolesets',
		UniversalReaction => 'universalReactions',
		Complex => 'complexes',
		Role => 'roles',
		BiomassTemplate => 'biomassTemplates',
		RoleAliasSet => 'roleAliasSets',
		RoleSetAliasSet => 'roleSetAliasSets',
		ComplexAliasSet => 'complexAliasSets',
	};
}


__PACKAGE__->meta->make_immutable;
1;
