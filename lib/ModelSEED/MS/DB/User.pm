########################################################################
# ModelSEED::MS::DB::User - This is the moose object corresponding to the User object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-19T08:21:34
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::IndexedObject;
use ModelSEED::MS::ObjectManager;
use ModelSEED::MS::Biochemistry;
use ModelSEED::MS::Annotation;
use ModelSEED::MS::Model;
use ModelSEED::MS::Mapping;
package ModelSEED::MS::DB::User;
extends ModelSEED::MS::IndexedObject;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::ObjectManager',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has login => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );
has password => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );
has email => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '' );
has firstname => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '' );
has lastname => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid');


# SUBOBJECTS:
has biochemistries => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Biochemistry]', type => 'link', metaclass => 'Typed');
has annotations => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Annotation]', type => 'link', metaclass => 'Typed');
has models => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Model]', type => 'link', metaclass => 'Typed');
has mappings => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Mapping]', type => 'link', metaclass => 'Typed');


# BUILDERS:
sub _buildUUID { return Data::UUID->new()->create_str(); }


# CONSTANTS:
sub _type { return 'User'; }


__PACKAGE__->meta->make_immutable;
1;
