########################################################################
# ModelSEED::MS::DB::Biochemistry - This is the moose object corresponding to the Biochemistry object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use ModelSEED::MS::Compartment;
use ModelSEED::MS::Compound;
use ModelSEED::MS::Reaction;
use ModelSEED::MS::ReactionInstance;
use ModelSEED::MS::Media;
use ModelSEED::MS::CompoundSet;
use ModelSEED::MS::ReactionSet;
use ModelSEED::MS::CompoundAliasSet;
use ModelSEED::MS::ReactionAliasSet;
use ModelSEED::MS::ReactionInstanceAliasSet;
use ModelSEED::MS::Cue;
use ModelSEED::MS::IndexedObject;
package ModelSEED::MS::DB::Biochemistry;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::IndexedObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::Store', type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', default => '1' );
has public => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', default => '0' );
has name => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has compartments => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Compartment]', type => 'child(Compartment)', metaclass => 'Typed');
has compounds => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Compound]', type => 'child(Compound)', metaclass => 'Typed');
has reactions => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Reaction]', type => 'child(Reaction)', metaclass => 'Typed');
has reactioninstances => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ReactionInstance]', type => 'child(ReactionInstance)', metaclass => 'Typed');
has media => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Media]', type => 'child(Media)', metaclass => 'Typed');
has compoundSets => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::CompoundSet]', type => 'child(CompoundSet)', metaclass => 'Typed');
has reactionSets => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ReactionSet]', type => 'child(ReactionSet)', metaclass => 'Typed');
has compoundAliasSets => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::CompoundAliasSet]', type => 'child(CompoundAliasSet)', metaclass => 'Typed');
has reactionAliasSets => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ReactionAliasSet]', type => 'child(ReactionAliasSet)', metaclass => 'Typed');
has reactioninstanceAliasSets => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ReactionInstanceAliasSet]', type => 'child(ReactionInstanceAliasSet)', metaclass => 'Typed');
has cues => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Cue]', type => 'encompassed(Cue)', metaclass => 'Typed');


# LINKS:


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Biochemistry'; }

my $typeToFunction = {
	ReactionSet => 'reactionSets',
	ReactionInstanceAliasSet => 'reactioninstanceAliasSets',
	CompoundAliasSet => 'compoundAliasSets',
	ReactionAliasSet => 'reactionAliasSets',
	Media => 'media',
	Compound => 'compounds',
	Reaction => 'reactions',
	ReactionInstance => 'reactioninstances',
	Cue => 'cues',
	Compartment => 'compartments',
	CompoundSet => 'compoundSets',
};
sub _typeToFunction {
	my ($self, $key) = @_;
	if (defined($key)) {
		return $typeToFunction->{$key};
	} else {
		return $typeToFunction;
	}
}

my $functionToType = {
	reactioninstanceAliasSets => 'ReactionInstanceAliasSet',
	reactionAliasSets => 'ReactionAliasSet',
	compounds => 'Compound',
	cues => 'Cue',
	reactionSets => 'ReactionSet',
	reactions => 'Reaction',
	compoundAliasSets => 'CompoundAliasSet',
	compartments => 'Compartment',
	media => 'Media',
	compoundSets => 'CompoundSet',
	reactioninstances => 'ReactionInstance',
};
sub _functionToType {
	my ($self, $key) = @_;
	if (defined($key)) {
		return $functionToType->{$key};
	} else {
		return $functionToType;
	}
}

my $attributes = ['uuid', 'modDate', 'locked', 'public', 'name'];
sub _attributes {
	return $attributes;
}

my $subobjects = ['compartments', 'compounds', 'reactions', 'reactioninstances', 'media', 'compoundSets', 'reactionSets', 'compoundAliasSets', 'reactionAliasSets', 'reactioninstanceAliasSets', 'cues'];
sub _subobjects {
	return $subobjects;
}


__PACKAGE__->meta->make_immutable;
1;
