########################################################################
# ModelSEED::MS::DB::CompoundAlias - This is the moose object corresponding to the CompoundAlias object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-28T22:59:34
########################################################################
use strict;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::CompoundAlias;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::CompoundAliasSet', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has compound_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has alias => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );




# LINKS:
has compound => (is => 'rw',lazy => 1,builder => '_buildcompound',isa => 'ModelSEED::MS::Compound', type => 'link(Biochemistry,Compound,uuid,compound_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildcompound {
	my ($self) = @_;
	return $self->getLinkedObject('Biochemistry','Compound','uuid',$self->compound_uuid());
}


# CONSTANTS:
sub _type { return 'CompoundAlias'; }


__PACKAGE__->meta->make_immutable;
1;
