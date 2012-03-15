########################################################################
# ModelSEED::MS::Biochemistry - This is the moose object corresponding to the Biochemistry object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-15T17:33:52
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::IndexedObject
use ModelSEED::MS::ObjectManager
use ModelSEED::MS::Compartment
use ModelSEED::MS::Compound
use ModelSEED::MS::Reaction
use ModelSEED::MS::Media
use ModelSEED::MS::Compoundset
use ModelSEED::MS::Reactionset
package ModelSEED::MS::Biochemistry
extends ModelSEED::MS::IndexedObject


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::ObjectManager',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', default => '1' );
has public => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', default => '0' );
has name => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', default => '' );


# SUBOBJECTS:
has compartments => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Compartment]', type => 'child', metaclass => 'Typed');
has compounds => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Compound]', type => 'child', metaclass => 'Typed');
has reactions => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Reaction]', type => 'child', metaclass => 'Typed');
has media => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Media]', type => 'child', metaclass => 'Typed');
has compoundsets => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Compoundset]', type => 'child', metaclass => 'Typed');
has reactionsets => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Reactionset]', type => 'child', metaclass => 'Typed');


# BUILDERS:
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Biochemistry'; }


# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
