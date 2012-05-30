########################################################################
# ModelSEED::MS::DB::GapfillingFormulation - This is the moose object corresponding to the GapfillingFormulation object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::GapfillingFormulation;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::GapfillingGeneCandidate;
use ModelSEED::MS::LazyHolder::ReactionSetMultiplier;
use ModelSEED::MS::LazyHolder::GapfillingSolution;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::ModelAnalysis', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid', printOrder => '0' );
has media_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );
has guaranteedReactions => ( is => 'rw', isa => 'ArrayRef[ModelSEED::uuid]', type => 'attribute', metaclass => 'Typed', required => 1, default => sub{return [];}, printOrder => '0' );
has blacklistedReactions => ( is => 'rw', isa => 'ArrayRef[ModelSEED::uuid]', type => 'attribute', metaclass => 'Typed', required => 1, default => sub{return [];}, printOrder => '0' );
has allowableCompartments => ( is => 'rw', isa => 'ArrayRef[ModelSEED::uuid]', type => 'attribute', metaclass => 'Typed', required => 1, default => sub{return [];}, printOrder => '0' );
has numberOfSolutions => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );
has biochemistry_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );
has reactionActivationBonus => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '0' );
has drainFluxMultiplier => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );
has directionalityMultiplier => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );
has deltaGMultiplier => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );
has noStructureMultiplier => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );
has noDeltaGMultiplier => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );
has biomassTransporterMultiplier => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );
has singleTransporterMultiplier => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );
has transporterMultiplier => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate', printOrder => '-1' );
has annotation_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has gapfillingGeneCandidates => (is => 'bare', coerce => 1, handles => { gapfillingGeneCandidates => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::GapfillingGeneCandidate::Lazy', type => 'encompassed(GapfillingGeneCandidate)', metaclass => 'Typed');
has reactionSetMultipliers => (is => 'bare', coerce => 1, handles => { reactionSetMultipliers => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::ReactionSetMultiplier::Lazy', type => 'encompassed(ReactionSetMultiplier)', metaclass => 'Typed');
has gapfillingSolutions => (is => 'bare', coerce => 1, handles => { gapfillingSolutions => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::GapfillingSolution::Lazy', type => 'encompassed(GapfillingSolution)', metaclass => 'Typed');


# LINKS:
has media => (is => 'rw',lazy => 1,builder => '_buildmedia',isa => 'ModelSEED::MS::Media', type => 'link(Biochemistry,Media,uuid,media_uuid)', metaclass => 'Typed',weak_ref => 1);
has annotation => (is => 'rw',lazy => 1,builder => '_buildannotation',isa => 'ModelSEED::MS::Annotation', type => 'link(ModelAnalysis,Annotation,uuid,annotation_uuid)', metaclass => 'Typed',weak_ref => 1);
has biochemistry => (is => 'rw',lazy => 1,builder => '_buildbiochemistry',isa => 'ModelSEED::MS::Biochemistry', type => 'link(ModelAnalysis,Biochemistry,uuid,biochemistry_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }
sub _buildmedia {
	my ($self) = @_;
	return $self->getLinkedObject('Biochemistry','Media','uuid',$self->media_uuid());
}
sub _buildannotation {
	my ($self) = @_;
	return $self->getLinkedObject('ModelAnalysis','Annotation','uuid',$self->annotation_uuid());
}
sub _buildbiochemistry {
	my ($self) = @_;
	return $self->getLinkedObject('ModelAnalysis','Biochemistry','uuid',$self->biochemistry_uuid());
}


# CONSTANTS:
sub _type { return 'GapfillingFormulation'; }
sub _typeToFunction {
	return {
		GapfillingSolution => 'gapfillingSolutions',
		GapfillingGeneCandidate => 'gapfillingGeneCandidates',
		ReactionSetMultiplier => 'reactionSetMultipliers',
	};
}


__PACKAGE__->meta->make_immutable;
1;
