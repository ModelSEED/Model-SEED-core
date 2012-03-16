########################################################################
# ModelSEED::MS::Compoundset - This is the moose object corresponding to the Compoundset object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-15T22:32:28
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject
use ModelSEED::MS::Biochemistry
use ModelSEED::MS::Compound
package ModelSEED::MS::Compoundset
extends ModelSEED::MS::BaseObject


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Biochemistry',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );
has id => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );
has name => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has searchname => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has class => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', default => 'unclassified' );
has type => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid');


# SUBOBJECTS:
has compounds => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Compound]', type => 'link', metaclass => 'Typed');


# BUILDERS:
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Compoundset'; }


# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
