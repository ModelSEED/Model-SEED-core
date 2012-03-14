########################################################################
# ModelSEED::MS::Biochemistry - This is the moose object corresponding to the Biochemistry object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-14T07:56:20
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::IndexedObject
use ModelSEED::MS::BiochemistryAlias
use ModelSEED::MS::Compartment
use ModelSEED::MS::Compound
use ModelSEED::MS::Reaction
use ModelSEED::MS::Media
use ModelSEED::MS::Compoundset
use ModelSEED::MS::Reactionset
package ModelSEED::MS::Biochemistry
extends ModelSEED::MS::IndexedObject


# PARENT:
has parent => (is => 'rw',required => 1,isa => 'ModelSEED::MS::ObjectManager',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'Str', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Int', default => '1' );
has public => ( is => 'rw', isa => 'Int', default => '0' );
has name => ( is => 'rw', isa => 'Str', default => '' );


# SUBOBJECTS:
has  => (is => 'rw',default => sub{return [];},isa => 'HashRef[ArrayRef]');
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Compartment]');
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Compound]');
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Reaction]');
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Media]');
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Compoundset]');
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Reactionset]');


# BUILDERS:
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Biochemistry'; }


# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
