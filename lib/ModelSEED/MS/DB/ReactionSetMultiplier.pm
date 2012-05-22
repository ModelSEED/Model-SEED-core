########################################################################
# ModelSEED::MS::DB::ReactionSetMultiplier - This is the moose object corresponding to the ReactionSetMultiplier object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::ReactionSetMultiplier;
use Moose;
use Moose::Util::TypeConstraints;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::Store', type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has feature_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has ortholog_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has orthogenome_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has similarityScore => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', printOrder => '-1' );
has distanceScore => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', printOrder => '-1' );
has reactions => ( is => 'rw', isa => 'ArrayRef', type => 'attribute', metaclass => 'Typed', required => 1, default => sub{return [];}, printOrder => '0' );




# LINKS:
has feature => (is => 'rw',lazy => 1,builder => '_buildfeature',isa => 'ModelSEED::MS::Feature', type => 'link(Annotation,Feature,uuid,feature_uuid)', metaclass => 'Typed',weak_ref => 1);
has ortholog => (is => 'rw',lazy => 1,builder => '_buildortholog',isa => 'ModelSEED::MS::Feature', type => 'link(ObjectManager,Feature,uuid,ortholog_uuid)', metaclass => 'Typed',weak_ref => 1);
has orthogenome => (is => 'rw',lazy => 1,builder => '_buildorthogenome',isa => 'ModelSEED::MS::Genome', type => 'link(ObjectManager,Genome,uuid,orthogenome_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildfeature {
	my ($self) = @_;
	return $self->getLinkedObject('Annotation','Feature','uuid',$self->feature_uuid());
}
sub _buildortholog {
	my ($self) = @_;
	return $self->getLinkedObject('ObjectManager','Feature','uuid',$self->ortholog_uuid());
}
sub _buildorthogenome {
	my ($self) = @_;
	return $self->getLinkedObject('ObjectManager','Genome','uuid',$self->orthogenome_uuid());
}


# CONSTANTS:
sub _type { return 'ReactionSetMultiplier'; }


__PACKAGE__->meta->make_immutable;
1;
