########################################################################
# ModelSEED::MS::ModelfbaCompound - This is the moose object corresponding to the ModelfbaCompound object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-14T07:56:20
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject
use ModelSEED::MS::ModelCompound
package ModelSEED::MS::ModelfbaCompound
extends ModelSEED::MS::BaseObject


# PARENT:
has parent => (is => 'rw',required => 1,isa => 'ModelSEED::MS::Modelfba',weak_ref => 1);


# ATTRIBUTES:
has modelfba_uuid => ( is => 'rw', isa => 'Str', required => 1 );
has modelcompound_uuid => ( is => 'rw', isa => 'Str', required => 1 );
has flux => ( is => 'rw', isa => 'Num' );
has lowerbound => ( is => 'rw', isa => 'Num', required => 1 );
has upperbound => ( is => 'rw', isa => 'Num', required => 1 );
has min => ( is => 'rw', isa => 'Num' );
has max => ( is => 'rw', isa => 'Num' );
has class => ( is => 'rw', isa => 'Str' );
has ko => ( is => 'rw', isa => 'Int', default => '0' );


# LINKS:
has compound => (is => 'rw',lazy => 1,builder => '_buildcompound',isa => 'ModelSEED::MS::ModelCompound',weak_ref => 1);


# BUILDERS:
sub _buildcompound {
	my ($self) = ;
	return $self->getLinkedObject('Model','ModelCompound','uuid',$self->modelcompound_uuid());
}


# CONSTANTS:
sub _type { return 'ModelfbaCompound'; }


# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
