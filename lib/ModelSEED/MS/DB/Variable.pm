########################################################################
# ModelSEED::MS::DB::Variable - This is the moose object corresponding to the Variable object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Variable;
use Moose;
use Moose::Util::TypeConstraints;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::FBAProblem', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid', printOrder => '0' );
has name => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );
has type => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );
has binary => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '0' );
has start => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '0' );
has upperBound => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '0' );
has lowerBound => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '0' );
has entity_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has index => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '-1', printOrder => '0' );
has primal => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );
has dualConstraint_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has upperBoundDualVariable_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has lowerBoundDualVariable_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '0' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# LINKS:
has dualConstraint => (is => 'rw',lazy => 1,builder => '_builddualConstraint',isa => 'ModelSEED::MS::Constraint', type => 'link(FBAProblem,Constraint,uuid,dualConstraint_uuid)', metaclass => 'Typed',weak_ref => 1);
has upperBoundDualVariable => (is => 'rw',lazy => 1,builder => '_buildupperBoundDualVariable',isa => 'ModelSEED::MS::Variable', type => 'link(FBAProblem,Variable,uuid,upperBoundDualVariable_uuid)', metaclass => 'Typed',weak_ref => 1);
has lowerBoundDualVariable => (is => 'rw',lazy => 1,builder => '_buildlowerBoundDualVariable',isa => 'ModelSEED::MS::Variable', type => 'link(FBAProblem,Variable,uuid,lowerBoundDualVariable_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _builddualConstraint {
	my ($self) = @_;
	return $self->getLinkedObject('FBAProblem','Constraint','uuid',$self->dualConstraint_uuid());
}
sub _buildupperBoundDualVariable {
	my ($self) = @_;
	return $self->getLinkedObject('FBAProblem','Variable','uuid',$self->upperBoundDualVariable_uuid());
}
sub _buildlowerBoundDualVariable {
	my ($self) = @_;
	return $self->getLinkedObject('FBAProblem','Variable','uuid',$self->lowerBoundDualVariable_uuid());
}


# CONSTANTS:
sub _type { return 'Variable'; }


__PACKAGE__->meta->make_immutable;
1;
