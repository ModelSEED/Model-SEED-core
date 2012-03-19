########################################################################
# ModelSEED::MS::DB::Complex - This is the moose object corresponding to the Complex object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-19T19:49:19
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::Mapping;
use ModelSEED::MS::ReactionRule;
use ModelSEED::MS::ComplexRole;
package ModelSEED::MS::DB::Complex;
extends ModelSEED::MS::BaseObject;


# PARENT:
#has parent => (is => 'rw',isa => 'ModelSEED::MS::Mapping',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );
has name => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has searchname => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', default => '' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid');


# SUBOBJECTS:
has reactionrules => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ReactionRule]', type => 'link', metaclass => 'Typed');
has complexroles => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ComplexRole]', type => 'encompassed', metaclass => 'Typed');


# BUILDERS:
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Complex'; }


__PACKAGE__->meta->make_immutable;
1;
