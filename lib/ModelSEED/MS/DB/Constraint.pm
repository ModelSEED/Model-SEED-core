########################################################################
# ModelSEED::MS::DB::Constraint - This is the moose object corresponding to the Constraint object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use ModelSEED::MS::ConstraintVariable;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::Constraint;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::FBAProblem', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has name => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has type => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has rightHandSide => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', required => 1 );
has equalityType => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );
has index => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', required => 1 );
has primal => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', required => 1 );
has entity_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );
has dualConstraint_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );
has dualVariable_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has constraintVariables => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ConstraintVariable]', type => 'child(ConstraintVariable)', metaclass => 'Typed');


# LINKS:
has dualConstraint => (is => 'rw',lazy => 1,builder => '_builddualConstraint',isa => 'ModelSEED::MS::Constraint', type => 'link(FBAProblem,Constraint,uuid,dualConstraint_uuid)', metaclass => 'Typed',weak_ref => 1);
has dualVariable => (is => 'rw',lazy => 1,builder => '_builddualVariable',isa => 'ModelSEED::MS::Constraint', type => 'link(FBAProblem,Constraint,uuid,dualVariable_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _builddualConstraint {
	my ($self) = @_;
	return $self->getLinkedObject('FBAProblem','Constraint','uuid',$self->dualConstraint_uuid());
}
sub _builddualVariable {
	my ($self) = @_;
	return $self->getLinkedObject('FBAProblem','Constraint','uuid',$self->dualVariable_uuid());
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
