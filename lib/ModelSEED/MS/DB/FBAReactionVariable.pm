########################################################################
# ModelSEED::MS::DB::FBAReactionVariable - This is the moose object corresponding to the FBAReactionVariable object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::FBAReactionVariable;
use Moose;
use Moose::Util::TypeConstraints;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::FBAResults', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has modelreaction_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has variableType => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has lowerBound => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has upperBound => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has min => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has max => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has value => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );




# LINKS:
has modelreaction => (is => 'rw',lazy => 1,builder => '_buildmodelreaction',isa => 'ModelSEED::MS::ModelReaction', type => 'link(Model,ModelReaction,uuid,modelreaction_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildmodelreaction {
	my ($self) = @_;
	return $self->getLinkedObject('Model','ModelReaction','uuid',$self->modelreaction_uuid());
}


# CONSTANTS:
sub _type { return 'FBAReactionVariable'; }


__PACKAGE__->meta->make_immutable;
1;
