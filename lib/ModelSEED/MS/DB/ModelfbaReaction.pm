########################################################################
# ModelSEED::MS::DB::ModelfbaReaction - This is the moose object corresponding to the ModelfbaReaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-24T02:58:25
########################################################################
use strict;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::ModelfbaReaction;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::FBASolution', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has modelreaction_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has class => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has ko => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );
has variables => ( is => 'rw', isa => 'HashRef', type => 'attribute', metaclass => 'Typed' );




# LINKS:
has modelreaction => (is => 'rw',lazy => 1,builder => '_buildmodelreaction',isa => 'ModelSEED::MS::ModelReaction', type => 'link(Model,ModelReaction,uuid,modelreaction_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildmodelreaction {
	my ($self) = @_;
	return $self->getLinkedObject('Model','ModelReaction','uuid',$self->modelreaction_uuid());
}


# CONSTANTS:
sub _type { return 'ModelfbaReaction'; }


__PACKAGE__->meta->make_immutable;
1;
