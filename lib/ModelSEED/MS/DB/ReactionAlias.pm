########################################################################
# ModelSEED::MS::DB::ReactionAlias - This is the moose object corresponding to the ReactionAlias object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::ReactionAlias;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::ReactionAliasSet', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has reaction_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has alias => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );




# LINKS:
has reaction => (is => 'rw',lazy => 1,builder => '_buildreaction',isa => 'ModelSEED::MS::Reaction', type => 'link(Biochemistry,Reaction,uuid,reaction_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildreaction {
	my ($self) = @_;
	return $self->getLinkedObject('Biochemistry','Reaction','uuid',$self->reaction_uuid());
}


# CONSTANTS:
sub _type { return 'ReactionAlias'; }

my $attributes = ['reaction_uuid', 'alias'];
sub _attributes {
	return $attributes;
}

my $subobjects = [];
sub _subobjects {
	return $subobjects;
}


__PACKAGE__->meta->make_immutable;
1;
