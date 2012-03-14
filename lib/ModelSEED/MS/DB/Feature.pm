########################################################################
# ModelSEED::MS::Feature - This is the moose object corresponding to the Feature object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-14T07:56:20
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject
use ModelSEED::MS::FeatureRoles
use ModelSEED::MS::Genome
package ModelSEED::MS::Feature
extends ModelSEED::MS::BaseObject


# PARENT:
has parent => (is => 'rw',required => 1,isa => 'ModelSEED::MS::Annotation',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'Str', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Int', default => '0' );
has id => ( is => 'rw', isa => 'Str', required => 1 );
has cksum => ( is => 'rw', isa => 'Str', default => '' );
has genome_uuid => ( is => 'rw', isa => 'Str', required => 1 );
has start => ( is => 'rw', isa => 'Int' );
has stop => ( is => 'rw', isa => 'Int' );


# SUBOBJECTS:
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::FeatureRoles]');


# LINKS:
has genome => (is => 'rw',lazy => 1,builder => '_buildgenome',isa => 'ModelSEED::MS::Genome',weak_ref => 1);


# BUILDERS:
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now()->datetime(); }
sub _buildgenome {
	my ($self) = ;
	return $self->getLinkedObject('Annotation','Genome','uuid',$self->genome_uuid());
}


# CONSTANTS:
sub _type { return 'Feature'; }


# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
