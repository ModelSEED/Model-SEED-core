########################################################################
# ModelSEED::MS::DB::FBAProblem - This is the moose object corresponding to the FBAProblem object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use ModelSEED::MS::ObjectiveTerm;
use ModelSEED::MS::Constraint;
use ModelSEED::MS::Variable;
use ModelSEED::MS::IndexedObject;
package ModelSEED::MS::DB::FBAProblem;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::IndexedObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::Store', type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has maximize => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed' );
has milp => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed' );
has decomposeReversibleFlux => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', required => 1 );
has decomposeReversibleDrainFlux => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', required => 1 );
has fluxUseVariables => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', required => 1 );
has drainfluxUseVariables => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', required => 1 );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has objectiveTerms => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ObjectiveTerm]', type => 'child(ObjectiveTerm)', metaclass => 'Typed');
has constraints => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Constraint]', type => 'child(Constraint)', metaclass => 'Typed');
has variables => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Variable]', type => 'child(Variable)', metaclass => 'Typed');


# LINKS:


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }


# CONSTANTS:
sub _type { return 'FBAProblem'; }

my $typeToFunction = {
	ObjectiveTerm => 'objectiveTerms',
	Constraint => 'constraints',
	Variable => 'variables',
};
sub _typeToFunction {
	my ($self, $key) = @_;
	if (defined($key)) {
		return $typeToFunction->{$key};
	} else {
		return $typeToFunction;
	}
}

my $functionToType = {
	constraints => 'Constraint',
	objectiveTerms => 'ObjectiveTerm',
	variables => 'Variable',
};
sub _functionToType {
	my ($self, $key) = @_;
	if (defined($key)) {
		return $functionToType->{$key};
	} else {
		return $functionToType;
	}
}

my $attributes = ['uuid', 'maximize', 'milp', 'decomposeReversibleFlux', 'decomposeReversibleDrainFlux', 'fluxUseVariables', 'drainfluxUseVariables'];
sub _attributes {
	return $attributes;
}

my $subobjects = ['objectiveTerms', 'constraints', 'variables'];
sub _subobjects {
	return $subobjects;
}


__PACKAGE__->meta->make_immutable;
1;
