########################################################################
# ModelSEED::MS::Mapping - This is the moose object corresponding to the Mapping object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-14T07:56:20
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::IndexedObject
use ModelSEED::MS::MappingAlias
use ModelSEED::MS::Role
use ModelSEED::MS::Roleset
use ModelSEED::MS::ReactionRule
use ModelSEED::MS::Complex
use ModelSEED::MS::Biochemistry
package ModelSEED::MS::Mapping
extends ModelSEED::MS::IndexedObject


# PARENT:
has parent => (is => 'rw',required => 1,isa => 'ModelSEED::MS::ObjectManager',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'Str', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Int', default => '0' );
has public => ( is => 'rw', isa => 'Int', default => '0' );
has name => ( is => 'rw', isa => 'Str', default => '' );
has biochemistry_uuid => ( is => 'rw', isa => 'Str', required => 1 );


# SUBOBJECTS:
has  => (is => 'rw',default => sub{return [];},isa => 'HashRef[ArrayRef]');
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Role]');
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Roleset]');
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ReactionRule]');
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Complex]');


# LINKS:
has biochemistry => (is => 'rw',lazy => 1,builder => '_buildbiochemistry',isa => 'ModelSEED::MS::Biochemistry',weak_ref => 1);


# BUILDERS:
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now()->datetime(); }
sub _buildbiochemistry {
	my ($self) = ;
	return $self->getLinkedObject('ObjectManager','Biochemistry','uuid',$self->biochemistry_uuid());
}


# CONSTANTS:
sub _type { return 'Mapping'; }


# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
