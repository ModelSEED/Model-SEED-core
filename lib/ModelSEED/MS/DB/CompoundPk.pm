########################################################################
# ModelSEED::MS::DB::CompoundPk - This is the moose object corresponding to the CompoundPk object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-19T19:49:19
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::Compound;
package ModelSEED::MS::DB::CompoundPk;
extends ModelSEED::MS::BaseObject;


# PARENT:
#has parent => (is => 'rw',isa => 'ModelSEED::MS::Compound',weak_ref => 1);


# ATTRIBUTES:
has compound_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has atom => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed' );
has pk => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', required => 1 );
has type => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );




# BUILDERS:
sub _buildModDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'CompoundPk'; }


__PACKAGE__->meta->make_immutable;
1;
