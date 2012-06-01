########################################################################
# ModelSEED::MS::DB::FBAProblem - This is the moose object corresponding to the FBAProblem object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::FBAProblem;
use ModelSEED::MS::IndexedObject;
use ModelSEED::MS::ObjectiveTerm;
use ModelSEED::MS::Constraint;
use ModelSEED::MS::Variable;
use ModelSEED::MS::Solution;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::IndexedObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::Store', type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', lazy => 1, builder => '_builduuid', type => 'attribute', metaclass => 'Typed');
has maximize => (is => 'rw', isa => 'Bool', default => '1', type => 'attribute', metaclass => 'Typed');
has milp => (is => 'rw', isa => 'Bool', default => '0', type => 'attribute', metaclass => 'Typed');
has decomposeReversibleFlux => (is => 'rw', isa => 'Bool', default => '0', type => 'attribute', metaclass => 'Typed');
has decomposeReversibleDrainFlux => (is => 'rw', isa => 'Bool', default => '0', type => 'attribute', metaclass => 'Typed');
has fluxUseVariables => (is => 'rw', isa => 'Bool', default => '0', type => 'attribute', metaclass => 'Typed');
has drainfluxUseVariables => (is => 'rw', isa => 'Bool', default => '0', type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has objectiveTerms => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(ObjectiveTerm)', metaclass => 'Typed', reader => '_objectiveTerms');
has constraints => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(Constraint)', metaclass => 'Typed', reader => '_constraints');
has variables => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(Variable)', metaclass => 'Typed', reader => '_variables');
has solutions => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(Solution)', metaclass => 'Typed', reader => '_solutions');


# LINKS:


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }


# CONSTANTS:
sub _type { return 'FBAProblem'; }

my $attributes = [
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'maximize',
            'default' => 1,
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'milp',
            'default' => 0,
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'len' => 32,
            'req' => 0,
            'printOrder' => 0,
            'name' => 'decomposeReversibleFlux',
            'default' => 0,
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'len' => 32,
            'req' => 0,
            'printOrder' => 0,
            'name' => 'decomposeReversibleDrainFlux',
            'default' => 0,
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'len' => 32,
            'req' => 0,
            'printOrder' => 0,
            'name' => 'fluxUseVariables',
            'default' => 0,
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'len' => 32,
            'req' => 0,
            'printOrder' => 0,
            'name' => 'drainfluxUseVariables',
            'default' => 0,
            'type' => 'Bool',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, maximize => 1, milp => 2, decomposeReversibleFlux => 3, decomposeReversibleDrainFlux => 4, fluxUseVariables => 5, drainfluxUseVariables => 6};
sub _attributes {
  my ($self, $key) = @_;
  if (defined($key)) {
    my $ind = $attribute_map->{$key};
    if (defined($ind)) {
      return $attributes->[$ind];
    } else {
      return undef;
    }
  } else {
    return $attributes;
  }
}

my $subobjects = [
          {
            'name' => 'objectiveTerms',
            'type' => 'child',
            'class' => 'ObjectiveTerm'
          },
          {
            'name' => 'constraints',
            'type' => 'child',
            'class' => 'Constraint'
          },
          {
            'name' => 'variables',
            'type' => 'child',
            'class' => 'Variable'
          },
          {
            'name' => 'solutions',
            'type' => 'child',
            'class' => 'Solution'
          }
        ];

my $subobject_map = {objectiveTerms => 0, constraints => 1, variables => 2, solutions => 3};
sub _subobjects {
  my ($self, $key) = @_;
  if (defined($key)) {
    my $ind = $subobject_map->{$key};
    if (defined($ind)) {
      return $subobjects->[$ind];
    } else {
      return undef;
    }
  } else {
    return $subobjects;
  }
}


# SUBOBJECT READERS:
around 'objectiveTerms' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('objectiveTerms');
};
around 'constraints' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('constraints');
};
around 'variables' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('variables');
};
around 'solutions' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('solutions');
};


__PACKAGE__->meta->make_immutable;
1;
