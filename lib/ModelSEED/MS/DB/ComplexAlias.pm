########################################################################
# ModelSEED::MS::DB::ComplexAlias - This is the moose object corresponding to the ComplexAlias object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::ComplexAlias;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::ComplexAliasSet', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has complex_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has alias => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );




# LINKS:
has complex => (is => 'rw',lazy => 1,builder => '_buildcomplex',isa => 'ModelSEED::MS::Complex', type => 'link(Mapping,Complex,uuid,complex_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildcomplex {
	my ($self) = @_;
	return $self->getLinkedObject('Mapping','Complex','uuid',$self->complex_uuid());
}


# CONSTANTS:
sub _type { return 'ComplexAlias'; }

my $attributes = ['complex_uuid', 'alias'];
sub _attributes {
	return $attributes;
}

my $subobjects = [];
sub _subobjects {
	return $subobjects;
}


__PACKAGE__->meta->make_immutable;
1;
