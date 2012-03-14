########################################################################
# ModelSEED::MS::Annotation - This is the moose object corresponding to the Annotation object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-14T07:56:20
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::IndexedObject
use ModelSEED::MS::AnnotationAlias
use ModelSEED::MS::Genome
use ModelSEED::MS::Feature
use ModelSEED::MS::Mapping
package ModelSEED::MS::Annotation
extends ModelSEED::MS::IndexedObject


# PARENT:
has parent => (is => 'rw',required => 1,isa => 'ModelSEED::MS::ObjectManager',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'Str', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Int', default => '0' );
has name => ( is => 'rw', isa => 'Str', default => '' );
has genome_uuid => ( is => 'rw', isa => 'Str', required => 1 );
has mapping_uuid => ( is => 'rw', isa => 'Str', required => 1 );


# SUBOBJECTS:
has  => (is => 'rw',default => sub{return [];},isa => 'HashRef[ArrayRef]');
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Genome]');
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Feature]');


# LINKS:
has mapping => (is => 'rw',lazy => 1,builder => '_buildmapping',isa => 'ModelSEED::MS::Mapping',weak_ref => 1);


# BUILDERS:
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now()->datetime(); }
sub _buildmapping {
	my ($self) = ;
	return $self->getLinkedObject('ObjectManager','Mapping','uuid',$self->mapping_uuid());
}


# CONSTANTS:
sub _type { return 'Annotation'; }


# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
