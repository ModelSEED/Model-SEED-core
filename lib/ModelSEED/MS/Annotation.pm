########################################################################
# ModelSEED::MS::Annotation - This is the moose object corresponding to the Annotation object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use ModelSEED::MS::DB::Annotation;
package ModelSEED::MS::Annotation;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::Annotation';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has definition => ( is => 'rw', isa => 'Str', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_builddefinition' );


#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _builddefinition {
	my ($self) = @_;
	return $self->createEquation({format=>"name",hashed=>0});
}


#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
=head3 createStandardFBAModel
Definition:
	ModelSEED::MS::Model = ModelSEED::MS::Annotation->createStandardFBAModel({
		prefix => "Seed",
		mapping => $self->mapping()
	});
Description:
	Creates a new model based on the annotations, the mapping, and the biochemistry
=cut
sub createStandardFBAModel {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
		prefix => "Seed",
		mapping => $self->mapping(),
	});
	my $mapping = $args->{mapping};
	my $biochem = $mapping->biochemistry();
	my $type = "Singlegenome";
	if (@{$self->genomes()} > 0) {
		$type = "Metagenome";
	}
	my $mdl = ModelSEED::MS::Model->new({
		id => $args->{prefix}.$self->id(),
		version => 0,
		type => $type,
		name => $self->name(),
		growth => 0,
		status => "Reconstruction started",
		current => 1,
		mapping_uuid => $mapping->uuid(),
		mapping => $mapping,
		biochemistry_uuid => $biochem->uuid(),
		biochemistry => $biochem,
		annotation_uuid => $self->uuid(),
		annotation => $self
	});
	$mdl->buildModelFromAnnotation();
	return $mdl;
}

=head3 classifyGenomeFromAnnotation
Definition:
	ModelSEED::MS::Model = ModelSEED::MS::Annotation->classifyGenomeFromAnnotation({});
Description:
	Classifies genome as gram negative, gram positive, archeae etc based on annotations
=cut
sub classifyGenomeFromAnnotation {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
	});
	
}

__PACKAGE__->meta->make_immutable;
1;
