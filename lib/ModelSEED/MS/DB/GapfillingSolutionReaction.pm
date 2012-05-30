########################################################################
# ModelSEED::MS::DB::GapfillingSolutionReaction - This is the moose object corresponding to the GapfillingSolutionReaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::GapfillingSolutionReaction;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::GfSolutionReactionGeneCandidate;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::GapfillingSolution', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has modelreaction_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );
has direction => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );




# SUBOBJECTS:
has gfSolutionReactionGeneCandidates => (is => 'bare', coerce => 1, handles => { gfSolutionReactionGeneCandidates => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::GfSolutionReactionGeneCandidate::Lazy', type => 'encompassed(GfSolutionReactionGeneCandidate)', metaclass => 'Typed');


# LINKS:
has modelreaction => (is => 'rw',lazy => 1,builder => '_buildmodelreaction',isa => 'ModelSEED::MS::ModelReaction', type => 'link(Model,ModelReaction,uuid,modelreaction_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildmodelreaction {
	my ($self) = @_;
	return $self->getLinkedObject('Model','ModelReaction','uuid',$self->modelreaction_uuid());
}


# CONSTANTS:
sub _type { return 'GapfillingSolutionReaction'; }
sub _typeToFunction {
	return {
		GfSolutionReactionGeneCandidate => 'gfSolutionReactionGeneCandidates',
	};
}


__PACKAGE__->meta->make_immutable;
1;
