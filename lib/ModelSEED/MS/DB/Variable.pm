########################################################################
# ModelSEED::MS::DB::Variable - This is the moose object corresponding to the Variable object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Variable;
use ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::FBAProblem', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', lazy => 1, builder => '_builduuid', type => 'attribute', metaclass => 'Typed');
has name => (is => 'rw', isa => 'Str', required => 1, type => 'attribute', metaclass => 'Typed');
has type => (is => 'rw', isa => 'Str', required => 1, type => 'attribute', metaclass => 'Typed');
has binary => (is => 'rw', isa => 'Bool', default => '0', type => 'attribute', metaclass => 'Typed');
has start => (is => 'rw', isa => 'Num', default => '0', type => 'attribute', metaclass => 'Typed');
has upperBound => (is => 'rw', isa => 'Num', default => '0', type => 'attribute', metaclass => 'Typed');
has lowerBound => (is => 'rw', isa => 'Num', default => '0', type => 'attribute', metaclass => 'Typed');
has entity_uuid => (is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed');
has index => (is => 'rw', isa => 'Int', default => '-1', type => 'attribute', metaclass => 'Typed');
has primal => (is => 'rw', isa => 'Bool', default => '1', type => 'attribute', metaclass => 'Typed');
has dualConstraint_uuid => (is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed');
has upperBoundDualVariable_uuid => (is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed');
has lowerBoundDualVariable_uuid => (is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# LINKS:
has dualConstraint => (is => 'rw', isa => 'ModelSEED::MS::Constraint', type => 'link(FBAProblem,constraints,dualConstraint_uuid)', metaclass => 'Typed', lazy => 1, builder => '_builddualConstraint', weak_ref => 1);
has upperBoundDualVariable => (is => 'rw', isa => 'ModelSEED::MS::Variable', type => 'link(FBAProblem,variables,upperBoundDualVariable_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildupperBoundDualVariable', weak_ref => 1);
has lowerBoundDualVariable => (is => 'rw', isa => 'ModelSEED::MS::Variable', type => 'link(FBAProblem,variables,lowerBoundDualVariable_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildlowerBoundDualVariable', weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _builddualConstraint {
  my ($self) = @_;
  return $self->getLinkedObject('FBAProblem','constraints',$self->dualConstraint_uuid());
}
sub _buildupperBoundDualVariable {
  my ($self) = @_;
  return $self->getLinkedObject('FBAProblem','variables',$self->upperBoundDualVariable_uuid());
}
sub _buildlowerBoundDualVariable {
  my ($self) = @_;
  return $self->getLinkedObject('FBAProblem','variables',$self->lowerBoundDualVariable_uuid());
}


# CONSTANTS:
sub _type { return 'Variable'; }

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
            'name' => 'binary',
            'default' => 0,
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'start',
            'default' => 0,
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'upperBound',
            'default' => 0,
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'lowerBound',
            'default' => 0,
            'type' => 'Num',
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
            'name' => 'dualConstraint_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'upperBoundDualVariable_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'lowerBoundDualVariable_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, name => 1, type => 2, binary => 3, start => 4, upperBound => 5, lowerBound => 6, entity_uuid => 7, index => 8, primal => 9, dualConstraint_uuid => 10, upperBoundDualVariable_uuid => 11, lowerBoundDualVariable_uuid => 12};
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

my $subobjects = [];

my $subobject_map = {};
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


__PACKAGE__->meta->make_immutable;
1;
