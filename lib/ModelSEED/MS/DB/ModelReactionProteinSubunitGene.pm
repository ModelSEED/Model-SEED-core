########################################################################
# ModelSEED::MS::DB::ModelReactionProteinSubunitGene - This is the moose object corresponding to the ModelReactionProteinSubunitGene object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::ModelReactionProteinSubunitGene;
use Moose;
use Moose::Util::TypeConstraints;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::ModelReactionProteinSubunit', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has feature_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );




# LINKS:
has feature => (is => 'rw',lazy => 1,builder => '_buildfeature',isa => 'ModelSEED::MS::Feature', type => 'link(Annotation,Feature,uuid,feature_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildfeature {
	my ($self) = @_;
	return $self->getLinkedObject('Annotation','Feature','uuid',$self->feature_uuid());
}


# CONSTANTS:
sub _type { return 'ModelReactionProteinSubunitGene'; }


__PACKAGE__->meta->make_immutable;
1;
