########################################################################
# ModelSEED::MS::DB::Variable - This is the moose object corresponding to the Variable object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-05-05T02:39:58
########################################################################
use strict;
use ModelSEED::MS::ConstraintVariable;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::Variable;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::FBAProblem', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has name => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has type => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has binary => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed' );
has start => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', required => 1 );
has upperBound => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', required => 1 );
has lowerBound => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', required => 1 );
has min => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', required => 1 );
has max => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', required => 1 );
has value => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', required => 1 );
has entity_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );
has index => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', required => 1 );
has primal => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', required => 1 );
has dualConstraint_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );
has upperBoundDualVariable_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );
has lowerBoundDualVariable_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has constraintVariables => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ConstraintVariable]', type => 'child(ConstraintVariable)', metaclass => 'Typed');


# LINKS:
has dualConstraint => (is => 'rw',lazy => 1,builder => '_builddualConstraint',isa => 'ModelSEED::MS::Constraint', type => 'link(FBAProblem,Constraint,uuid,dualConstraint_uuid)', metaclass => 'Typed',weak_ref => 1);
has upperBoundDualVariable => (is => 'rw',lazy => 1,builder => '_buildupperBoundDualVariable',isa => 'ModelSEED::MS::Constraint', type => 'link(FBAProblem,Constraint,uuid,upperBoundDualVariable_uuid)', metaclass => 'Typed',weak_ref => 1);
has lowerBoundDualVariable => (is => 'rw',lazy => 1,builder => '_buildlowerBoundDualVariable',isa => 'ModelSEED::MS::Constraint', type => 'link(FBAProblem,Constraint,uuid,lowerBoundDualVariable_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _builddualConstraint {
	my ($self) = @_;
	return $self->getLinkedObject('FBAProblem','Constraint','uuid',$self->dualConstraint_uuid());
}
sub _buildupperBoundDualVariable {
	my ($self) = @_;
	return $self->getLinkedObject('FBAProblem','Constraint','uuid',$self->upperBoundDualVariable_uuid());
}
sub _buildlowerBoundDualVariable {
	my ($self) = @_;
	return $self->getLinkedObject('FBAProblem','Constraint','uuid',$self->lowerBoundDualVariable_uuid());
}


# CONSTANTS:
sub _type { return 'Variable'; }
sub _typeToFunction {
	return {
		ConstraintVariable => 'constraintVariables',
	};
}


__PACKAGE__->meta->make_immutable;
1;
