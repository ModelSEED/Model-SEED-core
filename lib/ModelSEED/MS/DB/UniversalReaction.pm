########################################################################
# ModelSEED::MS::DB::UniversalReaction - This is the moose object corresponding to the UniversalReaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-29T05:19:03
########################################################################
use strict;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::UniversalReaction;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Mapping', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has type => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );
has reactioninstance_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1 );




# LINKS:
has reactioninstance => (is => 'rw',lazy => 1,builder => '_buildreactioninstance',isa => 'ModelSEED::MS::ReactionInstance', type => 'link(Biochemistry,ReactionInstance,uuid,reactioninstance_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildreactioninstance {
	my ($self) = @_;
	return $self->getLinkedObject('Biochemistry','ReactionInstance','uuid',$self->reactioninstance_uuid());
}


# CONSTANTS:
sub _type { return 'UniversalReaction'; }


__PACKAGE__->meta->make_immutable;
1;
