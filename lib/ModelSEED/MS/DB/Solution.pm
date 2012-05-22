########################################################################
# ModelSEED::MS::DB::Solution - This is the moose object corresponding to the Solution object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Solution;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::SolutionConstraint;
use ModelSEED::MS::LazyHolder::SolutionVariable;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::FBAProblem', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid', printOrder => '0' );
has status => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has method => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has feasible => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has objective => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', printOrder => '0' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has solutionconstraints => (is => 'bare', coerce => 1, handles => { solutionconstraints => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::SolutionConstraint::Lazy', type => 'child(SolutionConstraint)', metaclass => 'Typed');
has solutionvariables => (is => 'bare', coerce => 1, handles => { solutionvariables => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::SolutionVariable::Lazy', type => 'child(SolutionVariable)', metaclass => 'Typed');


# LINKS:


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }


# CONSTANTS:
sub _type { return 'Solution'; }
sub _typeToFunction {
	return {
		SolutionVariable => 'solutionvariables',
		SolutionConstraint => 'solutionconstraints',
	};
}


__PACKAGE__->meta->make_immutable;
1;
