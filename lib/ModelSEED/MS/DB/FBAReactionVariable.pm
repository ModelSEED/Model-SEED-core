########################################################################
# ModelSEED::MS::DB::FBAReactionVariable - This is the moose object corresponding to the FBAReactionVariable object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::FBAReactionVariable;
use ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::FBAResult', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has modelreaction_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');
has variableType => (is => 'rw', isa => 'Str', printOrder => '3', type => 'attribute', metaclass => 'Typed');
has lowerBound => (is => 'rw', isa => 'Str', printOrder => '7', type => 'attribute', metaclass => 'Typed');
has upperBound => (is => 'rw', isa => 'Str', printOrder => '8', type => 'attribute', metaclass => 'Typed');
has min => (is => 'rw', isa => 'Str', printOrder => '5', type => 'attribute', metaclass => 'Typed');
has max => (is => 'rw', isa => 'Str', printOrder => '6', type => 'attribute', metaclass => 'Typed');
has value => (is => 'rw', isa => 'Str', printOrder => '4', type => 'attribute', metaclass => 'Typed');


# LINKS:
has modelreaction => (is => 'rw', isa => 'ModelSEED::MS::ModelReaction', type => 'link(Model,modelreactions,modelreaction_uuid)', metaclass => 'Typed', lazy => 1, builder => '_build_modelreaction', weak_ref => 1);


# BUILDERS:
sub _build_modelreaction {
  my ($self) = @_;
  return $self->getLinkedObject('Model','modelreactions',$self->modelreaction_uuid());
}


# CONSTANTS:
sub _type { return 'FBAReactionVariable'; }

my $attributes = [
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'modelreaction_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'len' => 1,
            'req' => 0,
            'printOrder' => 3,
            'name' => 'variableType',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'len' => 1,
            'req' => 0,
            'printOrder' => 7,
            'name' => 'lowerBound',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'len' => 1,
            'req' => 0,
            'printOrder' => 8,
            'name' => 'upperBound',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'len' => 1,
            'req' => 0,
            'printOrder' => 5,
            'name' => 'min',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'len' => 1,
            'req' => 0,
            'printOrder' => 6,
            'name' => 'max',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'len' => 1,
            'req' => 0,
            'printOrder' => 4,
            'name' => 'value',
            'type' => 'Str',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {modelreaction_uuid => 0, variableType => 1, lowerBound => 2, upperBound => 3, min => 4, max => 5, value => 6};
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
