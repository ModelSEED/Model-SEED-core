########################################################################
# ModelSEED::MS::DB::ModelfbaReaction - This is the moose object corresponding to the ModelfbaReaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-03T07:07:13
########################################################################
use strict;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::ModelfbaReaction;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Modelfba', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has modelreaction_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has flux => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has lowerbound => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', required => 1 );
has upperbound => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', required => 1 );
has min => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has max => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has class => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has ko => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );




# LINKS:
has reaction => (is => 'rw',lazy => 1,builder => '_buildreaction',isa => 'ModelSEED::MS::ModelReaction', type => 'link(Model,ModelReaction,uuid,modelreaction_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildreaction {
	my ($self) = @_;
	return $self->getLinkedObject('Model','ModelReaction','uuid',$self->modelreaction_uuid());
}


# CONSTANTS:
sub _type { return 'ModelfbaReaction'; }


__PACKAGE__->meta->make_immutable;
1;
