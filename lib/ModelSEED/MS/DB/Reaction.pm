########################################################################
# ModelSEED::MS::DB::Reaction - This is the moose object corresponding to the Reaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use ModelSEED::MS::ReactionCue;
use ModelSEED::MS::ReactionReactionInstance;
use ModelSEED::MS::Reagent;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::Reaction;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Biochemistry', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );
has name => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has abbreviation => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has cksum => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has deltaG => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has deltaGErr => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has reversibility => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '=' );
has thermoReversibility => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has defaultProtons => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has status => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has reactionCues => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ReactionCue]', type => 'encompassed(ReactionCue)', metaclass => 'Typed');
has reactionreactioninstances => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ReactionReactionInstance]', type => 'encompassed(ReactionReactionInstance)', metaclass => 'Typed');
has reagents => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Reagent]', type => 'encompassed(Reagent)', metaclass => 'Typed');


# LINKS:
has id => (is => 'rw',lazy => 1,builder => '_buildid',isa => 'Str', type => 'id', metaclass => 'Typed');


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Reaction'; }

my $typeToFunction = {
	ReactionReactionInstance => 'reactionreactioninstances',
	Reagent => 'reagents',
	ReactionCue => 'reactionCues',
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
	reagents => 'Reagent',
	reactionreactioninstances => 'ReactionReactionInstance',
	reactionCues => 'ReactionCue',
};
sub _functionToType {
	my ($self, $key) = @_;
	if (defined($key)) {
		return $functionToType->{$key};
	} else {
		return $functionToType;
	}
}

my $attributes = ['uuid', 'modDate', 'locked', 'name', 'abbreviation', 'cksum', 'deltaG', 'deltaGErr', 'reversibility', 'thermoReversibility', 'defaultProtons', 'status'];
sub _attributes {
	return $attributes;
}

my $subobjects = ['reactionCues', 'reactionreactioninstances', 'reagents'];
sub _subobjects {
	return $subobjects;
}
sub _aliasowner { return 'Biochemistry'; }


__PACKAGE__->meta->make_immutable;
1;
