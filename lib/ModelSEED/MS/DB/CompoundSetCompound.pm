########################################################################
# ModelSEED::MS::DB::CompoundSetCompound - This is the moose object corresponding to the CompoundSetCompound object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::CompoundSetCompound;
use Moose;
use Moose::Util::TypeConstraints;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::CompoundSet', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has compound_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );




# LINKS:
has compound => (is => 'rw',lazy => 1,builder => '_buildcompound',isa => 'ModelSEED::MS::Compound', type => 'link(Biochemistry,Compound,uuid,compound_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildcompound {
	my ($self) = @_;
	return $self->getLinkedObject('Biochemistry','Compound','uuid',$self->compound_uuid());
}


# CONSTANTS:
sub _type { return 'CompoundSetCompound'; }


__PACKAGE__->meta->make_immutable;
1;
