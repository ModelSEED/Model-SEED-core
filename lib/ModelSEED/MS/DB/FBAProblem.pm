########################################################################
# ModelSEED::MS::DB::FBAProblem - This is the moose object corresponding to the FBAProblem object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::FBAProblem;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::ObjectiveTerm;
use ModelSEED::MS::LazyHolder::Constraint;
use ModelSEED::MS::LazyHolder::Variable;
use ModelSEED::MS::LazyHolder::Solution;
extends 'ModelSEED::MS::IndexedObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::Store', type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid', printOrder => '0' );
has maximize => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );
has milp => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '0' );
has decomposeReversibleFlux => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '0' );
has decomposeReversibleDrainFlux => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '0' );
has fluxUseVariables => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '0' );
has drainfluxUseVariables => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '0' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has objectiveTerms => (is => 'bare', coerce => 1, handles => { objectiveTerms => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::ObjectiveTerm::Lazy', type => 'child(ObjectiveTerm)', metaclass => 'Typed');
has constraints => (is => 'bare', coerce => 1, handles => { constraints => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::Constraint::Lazy', type => 'child(Constraint)', metaclass => 'Typed');
has variables => (is => 'bare', coerce => 1, handles => { variables => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::Variable::Lazy', type => 'child(Variable)', metaclass => 'Typed');
has solutions => (is => 'bare', coerce => 1, handles => { solutions => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::Solution::Lazy', type => 'child(Solution)', metaclass => 'Typed');


# LINKS:


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }


# CONSTANTS:
sub _type { return 'FBAProblem'; }
sub _typeToFunction {
	return {
		ObjectiveTerm => 'objectiveTerms',
		Constraint => 'constraints',
		Solution => 'solutions',
		Variable => 'variables',
	};
}


__PACKAGE__->meta->make_immutable;
1;
