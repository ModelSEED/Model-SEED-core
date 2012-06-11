########################################################################
# ModelSEED::MS::DB::Solution - This is the moose object corresponding to the Solution object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Solution;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::SolutionConstraint;
use ModelSEED::MS::SolutionVariable;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::FBAProblem', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', lazy => 1, builder => '_build_uuid', type => 'attribute', metaclass => 'Typed');
has status => (is => 'rw', isa => 'Str', printOrder => '0', type => 'attribute', metaclass => 'Typed');
has method => (is => 'rw', isa => 'Str', printOrder => '0', type => 'attribute', metaclass => 'Typed');
has feasible => (is => 'rw', isa => 'Bool', printOrder => '0', type => 'attribute', metaclass => 'Typed');
has objective => (is => 'rw', isa => 'Num', printOrder => '0', type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has solutionconstraints => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(SolutionConstraint)', metaclass => 'Typed', reader => '_solutionconstraints', printOrder => '-1');
has solutionvariables => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(SolutionVariable)', metaclass => 'Typed', reader => '_solutionvariables', printOrder => '-1');


# LINKS:


# BUILDERS:
sub _build_uuid { return Data::UUID->new()->create_str(); }


# CONSTANTS:
sub _type { return 'Solution'; }

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
            'name' => 'status',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'method',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'feasible',
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'objective',
            'type' => 'Num',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, status => 1, method => 2, feasible => 3, objective => 4};
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
            'name' => 'solutionconstraints',
            'type' => 'child',
            'class' => 'SolutionConstraint'
          },
          {
            'printOrder' => -1,
            'name' => 'solutionvariables',
            'type' => 'child',
            'class' => 'SolutionVariable'
          }
        ];

my $subobject_map = {solutionconstraints => 0, solutionvariables => 1};
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
around 'solutionconstraints' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('solutionconstraints');
};
around 'solutionvariables' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('solutionvariables');
};


__PACKAGE__->meta->make_immutable;
1;
