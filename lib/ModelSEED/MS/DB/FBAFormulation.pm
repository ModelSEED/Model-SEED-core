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
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::model_uuid', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has name => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', required => 1, default => '' );
has model_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );
has regulatorymodel_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );
has media_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has type => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );
has description => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '' );
has expressionData_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );
has growthConstraint => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => 'none' );
has thermodynamicConstraints => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => 'none' );
has allReversible => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );
has uptakeLimits => ( is => 'rw', isa => 'HashRef', type => 'attribute', metaclass => 'Typed', default => 'sub{return {};}' );
has numberOfSolutions => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', required => 1, default => '1' );
has geneKO => ( is => 'rw', isa => 'ArrayRef', type => 'attribute', metaclass => 'Typed', required => 1, default => 'sub{return [];}' );
has defaultMaxFlux => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', required => 1, default => '1000' );
has defaultMaxDrainFlux => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', required => 1, default => '1000' );
has defaultMinDrainFlux => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', required => 1, default => '-1000' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has fbaObjectiveTerms => (is => 'bare', coerce => 1, handles => { fbaObjectiveTerms => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::FBAObjectiveTerm::Lazy', type => 'encompassed(FBAObjectiveTerm)', metaclass => 'Typed');
has fbaCompoundConstraints => (is => 'bare', coerce => 1, handles => { fbaCompoundConstraints => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::FBACompoundConstraint::Lazy', type => 'encompassed(FBACompoundConstraint)', metaclass => 'Typed');
has fbaReactionConstraints => (is => 'bare', coerce => 1, handles => { fbaReactionConstraints => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::FBAReactionConstraint::Lazy', type => 'encompassed(FBAReactionConstraint)', metaclass => 'Typed');


# LINKS:
has media => (is => 'rw',lazy => 1,builder => '_buildmedia',isa => 'ModelSEED::MS::Media', type => 'link(Biochemistry,Media,uuid,media_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }
sub _buildmedia {
	my ($self) = @_;
	return $self->getLinkedObject('Biochemistry','Media','uuid',$self->media_uuid());
}


# CONSTANTS:
sub _type { return 'FBAFormulation'; }
sub _typeToFunction {
	return {
		FBAObjectiveTerm => 'fbaObjectiveTerms',
		FBAReactionConstraint => 'fbaReactionConstraints',
		FBACompoundConstraint => 'fbaCompoundConstraints',
	};
}


__PACKAGE__->meta->make_immutable;
1;
