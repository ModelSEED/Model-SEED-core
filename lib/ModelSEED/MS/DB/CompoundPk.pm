########################################################################
# ModelSEED::MS::DB::CompoundPk - This is the moose object corresponding to the CompoundPk object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::CompoundPk;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Compound', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has atom => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed' );
has pk => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', required => 1 );
has type => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );




# LINKS:


# BUILDERS:
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'CompoundPk'; }

my $attributes = ['modDate', 'atom', 'pk', 'type'];
sub _attributes {
	return $attributes;
}

my $subobjects = [];
sub _subobjects {
	return $subobjects;
}


__PACKAGE__->meta->make_immutable;
1;
