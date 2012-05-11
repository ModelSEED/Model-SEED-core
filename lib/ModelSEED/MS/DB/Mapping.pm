########################################################################
# ModelSEED::MS::DB::Mapping - This is the moose object corresponding to the Mapping object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use ModelSEED::MS::UniversalReaction;
use ModelSEED::MS::BiomassTemplate;
use ModelSEED::MS::Role;
use ModelSEED::MS::RoleSet;
use ModelSEED::MS::Complex;
use ModelSEED::MS::RoleSetAliasSet;
use ModelSEED::MS::RoleAliasSet;
use ModelSEED::MS::ComplexAliasSet;
use ModelSEED::MS::IndexedObject;
package ModelSEED::MS::DB::Mapping;
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
has name => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has biochemistry_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has universalReactions => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::UniversalReaction]', type => 'child(UniversalReaction)', metaclass => 'Typed');
has biomassTemplates => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::BiomassTemplate]', type => 'child(BiomassTemplate)', metaclass => 'Typed');
has roles => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Role]', type => 'child(Role)', metaclass => 'Typed');
has rolesets => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::RoleSet]', type => 'child(RoleSet)', metaclass => 'Typed');
has complexes => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Complex]', type => 'child(Complex)', metaclass => 'Typed');
has roleSetAliasSets => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::RoleSetAliasSet]', type => 'child(RoleSetAliasSet)', metaclass => 'Typed');
has roleAliasSets => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::RoleAliasSet]', type => 'child(RoleAliasSet)', metaclass => 'Typed');
has complexAliasSets => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ComplexAliasSet]', type => 'child(ComplexAliasSet)', metaclass => 'Typed');


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
