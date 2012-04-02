########################################################################
# ModelSEED::MS::DB::MediaCompound - This is the moose object corresponding to the MediaCompound object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-01T09:21:17
########################################################################
use strict;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::MediaCompound;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Media', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has media_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has compound_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has concentration => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0.001' );
has maxFlux => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '100' );
has minFlux => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '-100' );




# LINKS:
has compound => (is => 'rw',lazy => 1,builder => '_buildcompound',isa => 'ModelSEED::MS::Compound', type => 'link(Biochemistry,Compound,uuid,compound_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildcompound {
	my ($self) = @_;
	return $self->getLinkedObject('Biochemistry','Compound','uuid',$self->compound_uuid());
}


# CONSTANTS:
sub _type { return 'MediaCompound'; }


__PACKAGE__->meta->make_immutable;
1;
