########################################################################
# ModelSEED::MS::DB::ConstraintVariable - This is the moose object corresponding to the ConstraintVariable object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::ConstraintVariable;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Constraint', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has coefficient => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has variable_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1 );




# LINKS:
has variable => (is => 'rw',lazy => 1,builder => '_buildvariable',isa => 'ModelSEED::MS::Variable', type => 'link(FBAProblem,Variable,uuid,variable_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildvariable {
	my ($self) = @_;
	return $self->getLinkedObject('FBAProblem','Variable','uuid',$self->variable_uuid());
}


# CONSTANTS:
sub _type { return 'ConstraintVariable'; }

my $attributes = ['coefficient', 'variable_uuid'];
sub _attributes {
	return $attributes;
}

my $subobjects = [];
sub _subobjects {
	return $subobjects;
}


__PACKAGE__->meta->make_immutable;
1;
