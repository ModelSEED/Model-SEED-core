########################################################################
# ModelSEED::MS::CompoundPk - This is the moose object corresponding to the CompoundPk object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-14T07:56:20
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject
package ModelSEED::MS::CompoundPk
extends ModelSEED::MS::BaseObject


# PARENT:
has parent => (is => 'rw',required => 1,isa => 'ModelSEED::MS::Compound',weak_ref => 1);


# ATTRIBUTES:
has compound_uuid => ( is => 'rw', isa => 'Str', required => 1 );
has modDate => ( is => 'rw', isa => 'Str', lazy => 1, builder => '_buildmodDate' );
has atom => ( is => 'rw', isa => 'Int' );
has pk => ( is => 'rw', isa => 'Num', required => 1 );
has type => ( is => 'rw', isa => 'Str', required => 1 );


# BUILDERS:
sub _buildModDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'CompoundPk'; }


# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
