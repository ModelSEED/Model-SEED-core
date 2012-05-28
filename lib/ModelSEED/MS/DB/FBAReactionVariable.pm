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
has parent => (is => 'rw',isa => 'ModelSEED::MS::FBAResult', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has modelreaction_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );
has variableType => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '3' );
has lowerBound => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '7' );
has upperBound => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '8' );
has min => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '5' );
has max => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '6' );
has value => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '4' );




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
