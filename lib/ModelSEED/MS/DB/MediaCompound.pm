########################################################################
# ModelSEED::MS::DB::MediaCompound - This is the moose object corresponding to the MediaCompound object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::MediaCompound;
use Moose;
use Moose::Util::TypeConstraints;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Media', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has compound_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );
has concentration => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0.001', printOrder => '0' );
has maxFlux => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '100', printOrder => '0' );
has minFlux => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '-100', printOrder => '0' );




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
