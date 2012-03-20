########################################################################
# ModelSEED::MS::DB::ModelReactionTransports - This is the moose object corresponding to the ModelReactionTransports object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-20T05:05:02
########################################################################
use strict;
use namespace::autoclean;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::ModelReaction;
use ModelSEED::MS::ModelCompound;
package ModelSEED::MS::DB::ModelReactionTransports;
use Moose;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::ModelReaction', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has model_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has modelreaction_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has modelcompound_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has compartmentIndex => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', required => 1 );
has coefficient => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', required => 1 );




# LINKS:
has modelcompound => (is => 'rw',lazy => 1,builder => '_buildmodelcompound',isa => 'ModelSEED::MS::ModelCompound', type => 'link(Model,ModelCompound,uuid,modelcompound_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildmodelcompound {
	my ($self) = @_;
	return $self->getLinkedObject('Model','ModelCompound','uuid',$self->modelcompound_uuid());
}


# CONSTANTS:
sub _type { return 'ModelReactionTransports'; }


__PACKAGE__->meta->make_immutable;
1;
