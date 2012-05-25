########################################################################
# ModelSEED::MS::DB::GapfillingSolution - This is the moose object corresponding to the GapfillingSolution object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::GapfillingSolution;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::GapfillingSolutionReaction;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::GapfillingFormulation', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid', printOrder => '0' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate', printOrder => '-1' );
has solutionCost => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has gapfillingSolutionReactions => (is => 'bare', coerce => 1, handles => { gapfillingSolutionReactions => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::GapfillingSolutionReaction::Lazy', type => 'encompassed(GapfillingSolutionReaction)', metaclass => 'Typed');


# LINKS:


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'GapfillingSolution'; }
sub _typeToFunction {
	return {
		GapfillingSolutionReaction => 'gapfillingSolutionReactions',
	};
}


__PACKAGE__->meta->make_immutable;
1;
