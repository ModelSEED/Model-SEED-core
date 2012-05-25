########################################################################
# ModelSEED::MS::DB::ModelAnalysisModel - This is the moose object corresponding to the ModelAnalysisModel object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::ModelAnalysisModel;
use Moose;
use Moose::Util::TypeConstraints;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::ModelAnalysis', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has model_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '0' );




# LINKS:
has model => (is => 'rw',lazy => 1,builder => '_buildmodel',isa => 'ModelSEED::MS::Model', type => 'link(Store,Model,uuid,model_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildmodel {
	my ($self) = @_;
	return $self->getLinkedObject('Store','Model','uuid',$self->model_uuid());
}


# CONSTANTS:
sub _type { return 'ModelAnalysisModel'; }


__PACKAGE__->meta->make_immutable;
1;
