########################################################################
# ModelSEED::MS::DB::ModelfbaCompound - This is the moose object corresponding to the ModelfbaCompound object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-24T02:58:25
########################################################################
use strict;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::ModelfbaCompound;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::FBASolution', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has modelcompound_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has class => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has inMedia => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );
has variables => ( is => 'rw', isa => 'HashRef', type => 'attribute', metaclass => 'Typed' );




# LINKS:
has modelcompound => (is => 'rw',lazy => 1,builder => '_buildmodelcompound',isa => 'ModelSEED::MS::ModelCompound', type => 'link(Model,ModelCompound,uuid,modelcompound_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildmodelcompound {
	my ($self) = @_;
	return $self->getLinkedObject('Model','ModelCompound','uuid',$self->modelcompound_uuid());
}


# CONSTANTS:
sub _type { return 'ModelfbaCompound'; }


__PACKAGE__->meta->make_immutable;
1;
