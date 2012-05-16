########################################################################
# ModelSEED::MS::DB::Biochemistry - This is the moose object corresponding to the Biochemistry object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Biochemistry;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::Compartment;
use ModelSEED::MS::LazyHolder::Compound;
use ModelSEED::MS::LazyHolder::Reaction;
use ModelSEED::MS::LazyHolder::ReactionInstance;
use ModelSEED::MS::LazyHolder::Media;
use ModelSEED::MS::LazyHolder::CompoundSet;
use ModelSEED::MS::LazyHolder::ReactionSet;
use ModelSEED::MS::LazyHolder::CompoundAliasSet;
use ModelSEED::MS::LazyHolder::ReactionAliasSet;
use ModelSEED::MS::LazyHolder::ReactionInstanceAliasSet;
use ModelSEED::MS::LazyHolder::Cue;
extends 'ModelSEED::MS::IndexedObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::Store', type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid', printOrder => '0' );
has defaultNameSpace => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => 'ModelSEED', printOrder => '2' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate', printOrder => '-1' );
has locked => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '-1' );
has public => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '-1' );
has name => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '', printOrder => '1' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has compartments => (is => 'bare', coerce => 1, handles => { compartments => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::Compartment::Lazy', type => 'child(Compartment)', metaclass => 'Typed', printOrder => '0');
has compounds => (is => 'bare', coerce => 1, handles => { compounds => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::Compound::Lazy', type => 'child(Compound)', metaclass => 'Typed', printOrder => '3');
has reactions => (is => 'bare', coerce => 1, handles => { reactions => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::Reaction::Lazy', type => 'child(Reaction)', metaclass => 'Typed', printOrder => '4');
has reactioninstances => (is => 'bare', coerce => 1, handles => { reactioninstances => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::ReactionInstance::Lazy', type => 'child(ReactionInstance)', metaclass => 'Typed', printOrder => '5');
has media => (is => 'bare', coerce => 1, handles => { media => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::Media::Lazy', type => 'child(Media)', metaclass => 'Typed', printOrder => '2');
has compoundSets => (is => 'bare', coerce => 1, handles => { compoundSets => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::CompoundSet::Lazy', type => 'child(CompoundSet)', metaclass => 'Typed');
has reactionSets => (is => 'bare', coerce => 1, handles => { reactionSets => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::ReactionSet::Lazy', type => 'child(ReactionSet)', metaclass => 'Typed');
has compoundAliasSets => (is => 'bare', coerce => 1, handles => { compoundAliasSets => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::CompoundAliasSet::Lazy', type => 'child(CompoundAliasSet)', metaclass => 'Typed');
has reactionAliasSets => (is => 'bare', coerce => 1, handles => { reactionAliasSets => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::ReactionAliasSet::Lazy', type => 'child(ReactionAliasSet)', metaclass => 'Typed');
has reactioninstanceAliasSets => (is => 'bare', coerce => 1, handles => { reactioninstanceAliasSets => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::ReactionInstanceAliasSet::Lazy', type => 'child(ReactionInstanceAliasSet)', metaclass => 'Typed');
has cues => (is => 'bare', coerce => 1, handles => { cues => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::Cue::Lazy', type => 'encompassed(Cue)', metaclass => 'Typed', printOrder => '1');


# LINKS:


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Biochemistry'; }
sub _typeToFunction {
	return {
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
}


__PACKAGE__->meta->make_immutable;
1;
