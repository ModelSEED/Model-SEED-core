########################################################################
# ModelSEED::MS::DB::FBACompoundVariable - This is the moose object corresponding to the FBACompoundVariable object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-05-05T02:39:57
########################################################################
use strict;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::FBACompoundVariable;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::FBAResults', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has modelcompound_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has variableType => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has lowerBound => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has upperBound => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has min => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has max => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has value => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );




# LINKS:
has modelcompound => (is => 'rw',lazy => 1,builder => '_buildmodelcompound',isa => 'ModelSEED::MS::ModelCompound', type => 'link(Model,ModelCompound,uuid,modelcompound_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildmodelcompound {
	my ($self) = @_;
	return $self->getLinkedObject('Model','ModelCompound','uuid',$self->modelcompound_uuid());
}


# CONSTANTS:
sub _type { return 'FBACompoundVariable'; }


__PACKAGE__->meta->make_immutable;
1;
