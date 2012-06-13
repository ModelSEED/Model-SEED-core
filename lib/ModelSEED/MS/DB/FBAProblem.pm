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
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', lazy => 1, builder => '_build_uuid', type => 'attribute', metaclass => 'Typed');
has maximize => (is => 'rw', isa => 'Bool', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has milp => (is => 'rw', isa => 'Bool', printOrder => '0', default => '0', type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has objectiveTerms => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(ObjectiveTerm)', metaclass => 'Typed', reader => '_objectiveTerms', printOrder => '-1');
has constraints => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(Constraint)', metaclass => 'Typed', reader => '_constraints', printOrder => '-1');
has variables => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(Variable)', metaclass => 'Typed', reader => '_variables', printOrder => '-1');
has solutions => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(Solution)', metaclass => 'Typed', reader => '_solutions', printOrder => '-1');


# LINKS:


# BUILDERS:
sub _build_uuid { return Data::UUID->new()->create_str(); }


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
          }
        ];

my $attribute_map = {uuid => 0, maximize => 1, milp => 2};
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
            'printOrder' => -1,
            'name' => 'objectiveTerms',
            'type' => 'child',
            'class' => 'ObjectiveTerm'
          },
          {
            'printOrder' => -1,
            'name' => 'constraints',
            'type' => 'child',
            'class' => 'Constraint'
          },
          {
            'printOrder' => -1,
            'name' => 'variables',
            'type' => 'child',
            'class' => 'Variable'
          },
          {
            'printOrder' => -1,
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
