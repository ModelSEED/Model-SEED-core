########################################################################
# ModelSEED::MS::DB::FBAFormulation - This is the moose object corresponding to the FBAFormulation object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::FBAFormulation;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::FBAObjectiveTerm;
use ModelSEED::MS::LazyHolder::FBACompoundConstraint;
use ModelSEED::MS::LazyHolder::FBAReactionConstraint;
use ModelSEED::MS::LazyHolder::FBAResult;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::ModelAnalysis', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid', printOrder => '0' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate', printOrder => '-1' );
has name => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', required => 1, default => '', printOrder => '0' );
has model_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has regulatorymodel_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has media_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );
has biochemistry_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );
has type => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );
has description => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '', printOrder => '0' );
has expressionData_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has growthConstraint => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => 'none', printOrder => '0' );
has thermodynamicConstraints => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => 'none', printOrder => '0' );
has allReversible => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '0' );
has uptakeLimits => ( is => 'rw', isa => 'HashRef', type => 'attribute', metaclass => 'Typed', default => sub{return {};}, printOrder => '0' );
has geneKO => ( is => 'rw', isa => 'ArrayRef', type => 'attribute', metaclass => 'Typed', required => 1, default => sub{return [];}, printOrder => '0' );
has defaultMaxFlux => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', required => 1, default => '1000', printOrder => '0' );
has defaultMaxDrainFlux => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', required => 1, default => '1000', printOrder => '0' );
has defaultMinDrainFlux => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', required => 1, default => '-1000', printOrder => '0' );
has maximizeObjective => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', required => 1, default => '1', printOrder => '0' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has fbaObjectiveTerms => (is => 'bare', coerce => 1, handles => { fbaObjectiveTerms => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::FBAObjectiveTerm::Lazy', type => 'encompassed(FBAObjectiveTerm)', metaclass => 'Typed');
has fbaCompoundConstraints => (is => 'bare', coerce => 1, handles => { fbaCompoundConstraints => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::FBACompoundConstraint::Lazy', type => 'encompassed(FBACompoundConstraint)', metaclass => 'Typed');
has fbaReactionConstraints => (is => 'bare', coerce => 1, handles => { fbaReactionConstraints => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::FBAReactionConstraint::Lazy', type => 'encompassed(FBAReactionConstraint)', metaclass => 'Typed');
has fbaResults => (is => 'bare', coerce => 1, handles => { fbaResults => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::FBAResult::Lazy', type => 'encompassed(FBAResult)', metaclass => 'Typed');


# LINKS:
has media => (is => 'rw',lazy => 1,builder => '_buildmedia',isa => 'ModelSEED::MS::Media', type => 'link(Biochemistry,Media,uuid,media_uuid)', metaclass => 'Typed',weak_ref => 1);
has biochemistry => (is => 'rw',lazy => 1,builder => '_buildbiochemistry',isa => 'ModelSEED::MS::Biochemistry', type => 'link(ModelAnalysis,Biochemistry,uuid,biochemistry_uuid)', metaclass => 'Typed',weak_ref => 1);
has model => (is => 'rw',lazy => 1,builder => '_buildmodel',isa => 'ModelSEED::MS::Model', type => 'link(ModelAnalysis,Model,uuid,model_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }
sub _buildmedia {
	my ($self) = @_;
	return $self->getLinkedObject('Biochemistry','Media','uuid',$self->media_uuid());
}
sub _buildbiochemistry {
	my ($self) = @_;
	return $self->getLinkedObject('ModelAnalysis','Biochemistry','uuid',$self->biochemistry_uuid());
}
sub _buildmodel {
	my ($self) = @_;
	return $self->getLinkedObject('ModelAnalysis','Model','uuid',$self->model_uuid());
}


# CONSTANTS:
sub _type { return 'FBAFormulation'; }
sub _typeToFunction {
	return {
		FBAObjectiveTerm => 'fbaObjectiveTerms',
		FBAResult => 'fbaResults',
		FBAReactionConstraint => 'fbaReactionConstraints',
		FBACompoundConstraint => 'fbaCompoundConstraints',
	};
}


__PACKAGE__->meta->make_immutable;
1;
