########################################################################
# ModelSEED::MS::DB::User - This is the moose object corresponding to the User object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-20T19:18:07
########################################################################
use strict;
use namespace::autoclean;
use ModelSEED::MS::IndexedObject;
use ModelSEED::MS::ObjectManager;
use ModelSEED::MS::Biochemistry;
use ModelSEED::MS::Annotation;
use ModelSEED::MS::Model;
use ModelSEED::MS::Mapping;
package ModelSEED::MS::DB::User;
use Moose;
extends 'ModelSEED::MS::IndexedObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::ObjectManager', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has login => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );
has password => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );
has email => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '' );
has firstname => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '' );
has lastname => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has biochemistries => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Biochemistry]', type => 'solink(ObjectManager,Biochemistry,uuid,biochemistry_uuid)', metaclass => 'Typed',weak_ref => 1);
has annotations => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Annotation]', type => 'solink(ObjectManager,Annotation,uuid,annotation_uuid)', metaclass => 'Typed',weak_ref => 1);
has models => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Model]', type => 'solink(ObjectManager,Model,uuid,model_uuid)', metaclass => 'Typed',weak_ref => 1);
has mappings => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Mapping]', type => 'solink(ObjectManager,Mapping,uuid,mapping_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }


# CONSTANTS:
sub _type { return 'User'; }


__PACKAGE__->meta->make_immutable;
1;
