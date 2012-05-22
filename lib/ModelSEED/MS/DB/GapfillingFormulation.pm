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
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::Store', type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid', printOrder => '0' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate', printOrder => '-1' );
has name => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', required => 1, default => '', printOrder => '0' );
has fbaformulation_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );
has biochemistry_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );
has numberOfSolutions => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );
has balancedReactionsOnly => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );
has reactionActivationBonus => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '0' );
has drainFluxMultiplier => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );
has directionalityMultiplier => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );
has deltaGMultiplier => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );
has noStructureMultiplier => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );
has noDeltaGMultiplier => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );
has biomassTransporterMultiplier => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );
has singleTransporterMultiplier => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );
has transporterMultiplier => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );
has blacklistedReactions => ( is => 'rw', isa => 'ArrayRef', type => 'attribute', metaclass => 'Typed', required => 1, default => sub{return [];}, printOrder => '0' );
has allowableUnbalancedReactions => ( is => 'rw', isa => 'ArrayRef', type => 'attribute', metaclass => 'Typed', required => 1, default => sub{return [];}, printOrder => '0' );
has allowableCompartments => ( is => 'rw', isa => 'ArrayRef', type => 'attribute', metaclass => 'Typed', required => 1, default => sub{return [];}, printOrder => '0' );
has guaranteedReactions => ( is => 'rw', isa => 'ArrayRef', type => 'attribute', metaclass => 'Typed', required => 1, default => sub{return [];}, printOrder => '0' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has gapfillingGeneCandidates => (is => 'bare', coerce => 1, handles => { gapfillingGeneCandidates => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::GapfillingGeneCandidate::Lazy', type => 'encompassed(GapfillingGeneCandidate)', metaclass => 'Typed');
has reactionSetMultipliers => (is => 'bare', coerce => 1, handles => { reactionSetMultipliers => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::ReactionSetMultiplier::Lazy', type => 'encompassed(ReactionSetMultiplier)', metaclass => 'Typed');


# LINKS:


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'GapfillingFormulation'; }
sub _typeToFunction {
	return {
		GapfillingGeneCandidate => 'gapfillingGeneCandidates',
		ReactionSetMultiplier => 'reactionSetMultipliers',
	};
}


__PACKAGE__->meta->make_immutable;
1;
