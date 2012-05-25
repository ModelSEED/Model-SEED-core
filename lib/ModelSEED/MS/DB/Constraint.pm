########################################################################
# ModelSEED::MS::DB::Constraint - This is the moose object corresponding to the Constraint object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Constraint;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::ConstraintVariable;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::FBAProblem', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid', printOrder => '0' );
has name => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );
has type => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );
has rightHandSide => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '0' );
has equalityType => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '=', printOrder => '0' );
has index => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '-1', printOrder => '0' );
has primal => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );
has entity_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has dualConstraint_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has dualVariable_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '0' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has constraintVariables => (is => 'bare', coerce => 1, handles => { constraintVariables => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::ConstraintVariable::Lazy', type => 'child(ConstraintVariable)', metaclass => 'Typed');


# LINKS:
has dualConstraint => (is => 'rw',lazy => 1,builder => '_builddualConstraint',isa => 'ModelSEED::MS::Constraint', type => 'link(FBAProblem,Constraint,uuid,dualConstraint_uuid)', metaclass => 'Typed',weak_ref => 1);
has dualVariable => (is => 'rw',lazy => 1,builder => '_builddualVariable',isa => 'ModelSEED::MS::Variable', type => 'link(FBAProblem,Variable,uuid,dualVariable_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _builddualConstraint {
	my ($self) = @_;
	return $self->getLinkedObject('FBAProblem','Constraint','uuid',$self->dualConstraint_uuid());
}
sub _builddualVariable {
	my ($self) = @_;
	return $self->getLinkedObject('FBAProblem','Variable','uuid',$self->dualVariable_uuid());
}


# CONSTANTS:
sub _type { return 'Constraint'; }
sub _typeToFunction {
	return {
		ConstraintVariable => 'constraintVariables',
	};
}


__PACKAGE__->meta->make_immutable;
1;
