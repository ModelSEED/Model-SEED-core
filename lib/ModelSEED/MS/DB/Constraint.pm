########################################################################
# ModelSEED::MS::DB::Constraint - This is the moose object corresponding to the Constraint object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Constraint;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::ConstraintVariable;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::FBAProblem', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', lazy => 1, builder => '_builduuid', type => 'attribute', metaclass => 'Typed');
has name => (is => 'rw', isa => 'Str', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');
has type => (is => 'rw', isa => 'Str', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');
has rightHandSide => (is => 'rw', isa => 'Num', printOrder => '0', default => '0', type => 'attribute', metaclass => 'Typed');
has equalityType => (is => 'rw', isa => 'Str', printOrder => '0', default => '=', type => 'attribute', metaclass => 'Typed');
has index => (is => 'rw', isa => 'Int', printOrder => '0', default => '-1', type => 'attribute', metaclass => 'Typed');
has primal => (is => 'rw', isa => 'Bool', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has entity_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', type => 'attribute', metaclass => 'Typed');
has dualConstraint_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', type => 'attribute', metaclass => 'Typed');
has dualVariable_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has constraintVariables => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(ConstraintVariable)', metaclass => 'Typed', reader => '_constraintVariables', printOrder => '-1');


# LINKS:
has dualConstraint => (is => 'rw', isa => 'ModelSEED::MS::Constraint', type => 'link(FBAProblem,constraints,dualConstraint_uuid)', metaclass => 'Typed', lazy => 1, builder => '_builddualConstraint', weak_ref => 1);
has dualVariable => (is => 'rw', isa => 'ModelSEED::MS::Variable', type => 'link(FBAProblem,variables,dualVariable_uuid)', metaclass => 'Typed', lazy => 1, builder => '_builddualVariable', weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _builddualConstraint {
  my ($self) = @_;
  return $self->getLinkedObject('FBAProblem','constraints',$self->dualConstraint_uuid());
}
sub _builddualVariable {
  my ($self) = @_;
  return $self->getLinkedObject('FBAProblem','variables',$self->dualVariable_uuid());
}


# CONSTANTS:
sub _type { return 'Constraint'; }

my $attributes = [
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'name',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'type',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'rightHandSide',
            'default' => 0,
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'len' => 1,
            'req' => 0,
            'printOrder' => 0,
            'name' => 'equalityType',
            'default' => '=',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'len' => 1,
            'req' => 0,
            'printOrder' => 0,
            'name' => 'index',
            'default' => -1,
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'len' => 1,
            'req' => 0,
            'printOrder' => 0,
            'name' => 'primal',
            'default' => 1,
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'entity_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'dualConstraint_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'dualVariable_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, name => 1, type => 2, rightHandSide => 3, equalityType => 4, index => 5, primal => 6, entity_uuid => 7, dualConstraint_uuid => 8, dualVariable_uuid => 9};
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
            'name' => 'constraintVariables',
            'type' => 'child',
            'class' => 'ConstraintVariable'
          }
        ];

my $subobject_map = {constraintVariables => 0};
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
around 'constraintVariables' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('constraintVariables');
};


__PACKAGE__->meta->make_immutable;
1;
