########################################################################
# ModelSEED::MS::DB::ModelAnalysisMapping - This is the moose object corresponding to the ModelAnalysisMapping object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::ModelAnalysisMapping;
use Moose;
use Moose::Util::TypeConstraints;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::ModelAnalysis', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has mapping_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '0' );




# LINKS:
has mapping => (is => 'rw',lazy => 1,builder => '_buildmapping',isa => 'ModelSEED::MS::Mapping', type => 'link(Store,Mapping,uuid,mapping_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildmapping {
	my ($self) = @_;
	return $self->getLinkedObject('Store','Mapping','uuid',$self->mapping_uuid());
}


# CONSTANTS:
sub _type { return 'ModelAnalysisMapping'; }


__PACKAGE__->meta->make_immutable;
1;
