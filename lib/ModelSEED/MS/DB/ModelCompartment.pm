########################################################################
# ModelSEED::MS::ModelCompartment - This is the moose object corresponding to the ModelCompartment object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-14T07:56:20
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject
use ModelSEED::MS::Compartment
package ModelSEED::MS::ModelCompartment
extends ModelSEED::MS::BaseObject


# PARENT:
has parent => (is => 'rw',required => 1,isa => 'ModelSEED::MS::Model',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'Str', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Int', default => '0' );
has model_uuid => ( is => 'rw', isa => 'Str', required => 1 );
has compartment_uuid => ( is => 'rw', isa => 'Str', required => 1 );
has compartmentIndex => ( is => 'rw', isa => 'Int', required => 1 );
has label => ( is => 'rw', isa => 'Str', default => '' );
has pH => ( is => 'rw', isa => 'Num', default => '7' );
has potential => ( is => 'rw', isa => 'Num', default => '0' );


# LINKS:
has compartment => (is => 'rw',lazy => 1,builder => '_buildcompartment',isa => 'ModelSEED::MS::Compartment',weak_ref => 1);


# BUILDERS:
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now()->datetime(); }
sub _buildcompartment {
	my ($self) = ;
	return $self->getLinkedObject('Biochemistry','Compartment','uuid',$self->compartment_uuid());
}


# CONSTANTS:
sub _type { return 'ModelCompartment'; }


# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
