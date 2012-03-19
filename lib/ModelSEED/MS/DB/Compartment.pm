########################################################################
# ModelSEED::MS::DB::Compartment - This is the moose object corresponding to the Compartment object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-19T19:49:19
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::Biochemistry;
package ModelSEED::MS::DB::Compartment;
extends ModelSEED::MS::BaseObject;


# PARENT:
#has parent => (is => 'rw',isa => 'ModelSEED::MS::Biochemistry',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1, lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );
has id => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );
has name => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', default => '' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid');


# BUILDERS:
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Compartment'; }


__PACKAGE__->meta->make_immutable;
1;
