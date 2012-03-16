########################################################################
# ModelSEED::MS::ModelfbaReaction - This is the moose object corresponding to the ModelfbaReaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-15T22:32:28
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject
use ModelSEED::MS::Modelfba
use ModelSEED::MS::ModelReaction
package ModelSEED::MS::ModelfbaReaction
extends ModelSEED::MS::BaseObject


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Modelfba',weak_ref => 1);


# ATTRIBUTES:
has modelfba_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has modelreaction_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has flux => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has lowerbound => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', required => 1 );
has upperbound => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', required => 1 );
has min => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has max => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has class => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has ko => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );




# LINKS:
has reaction => (is => 'rw',lazy => 1,builder => '_buildreaction',isa => 'ModelSEED::MS::ModelReaction',weak_ref => 1);


# BUILDERS:
sub _buildreaction {
	my ($self) = ;
	return $self->getLinkedObject('Model','ModelReaction','uuid',$self->modelreaction_uuid());
}


# CONSTANTS:
sub _type { return 'ModelfbaReaction'; }


# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
