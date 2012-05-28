########################################################################
# ModelSEED::MS::DB::ModelAnalysisAnnotation - This is the moose object corresponding to the ModelAnalysisAnnotation object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::ModelAnalysisAnnotation;
use Moose;
use Moose::Util::TypeConstraints;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::ModelAnalysis', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has annotation_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '0' );




# LINKS:
has annotation => (is => 'rw',lazy => 1,builder => '_buildannotation',isa => 'ModelSEED::MS::Annotation', type => 'link(Store,Annotation,uuid,annotation_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildannotation {
	my ($self) = @_;
	return $self->getLinkedObject('Store','Annotation','uuid',$self->annotation_uuid());
}


# CONSTANTS:
sub _type { return 'ModelAnalysisAnnotation'; }


__PACKAGE__->meta->make_immutable;
1;
