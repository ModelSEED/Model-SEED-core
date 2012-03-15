########################################################################
# ModelSEED::MS::Genome - This is the moose object corresponding to the Genome object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-15T17:33:52
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject
use ModelSEED::MS::Annotation
package ModelSEED::MS::Genome
extends ModelSEED::MS::BaseObject


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Annotation',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has id => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );
has name => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has source => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', required => 1 );
has class => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has taxonomy => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has cksum => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has size => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed' );
has genes => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed' );
has gc => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has etcType => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed' );


# BUILDERS:
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Genome'; }


# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
