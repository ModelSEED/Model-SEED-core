########################################################################
# ModelSEED::MS::DB::Reaction - This is the moose object corresponding to the Reaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Reaction;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::ReactionCue;
use ModelSEED::MS::LazyHolder::ReactionReactionInstance;
use ModelSEED::MS::LazyHolder::Reagent;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Biochemistry', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid', printOrder => '0' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate', printOrder => '-1' );
has locked => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '-1' );
has name => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '', printOrder => '1' );
has abbreviation => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '', printOrder => '2' );
has cksum => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '', printOrder => '-1' );
has deltaG => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', printOrder => '8' );
has deltaGErr => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', printOrder => '9' );
has reversibility => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '=', printOrder => '5' );
has thermoReversibility => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '6' );
has defaultProtons => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', printOrder => '7' );
has status => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '10' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has reactionCues => (is => 'bare', coerce => 1, handles => { reactionCues => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::ReactionCue::Lazy', type => 'encompassed(ReactionCue)', metaclass => 'Typed');
has reactionreactioninstances => (is => 'bare', coerce => 1, handles => { reactionreactioninstances => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::ReactionReactionInstance::Lazy', type => 'encompassed(ReactionReactionInstance)', metaclass => 'Typed');
has reagents => (is => 'bare', coerce => 1, handles => { reagents => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::Reagent::Lazy', type => 'encompassed(Reagent)', metaclass => 'Typed');


# LINKS:
has id => (is => 'rw',lazy => 1,builder => '_buildid',isa => 'Str', type => 'id', metaclass => 'Typed');


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Reaction'; }
sub _typeToFunction {
	return {
		ReactionReactionInstance => 'reactionreactioninstances',
		Reagent => 'reagents',
		ReactionCue => 'reactionCues',
	};
}
sub _aliasowner { return 'Biochemistry'; }


__PACKAGE__->meta->make_immutable;
1;
