########################################################################
# ModelSEED::MS::DB::FBAConstraint - This is the moose object corresponding to the FBAConstraint object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::FBAConstraint;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::FBAConstraintVariable;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::FBAFormulation', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has name => (is => 'rw', isa => 'Str', printOrder => '0', default => '0', type => 'attribute', metaclass => 'Typed');
has rhs => (is => 'rw', isa => 'Num', printOrder => '0', default => '0', type => 'attribute', metaclass => 'Typed');
has sign => (is => 'rw', isa => 'Str', printOrder => '0', default => '0', type => 'attribute', metaclass => 'Typed');


# SUBOBJECTS:
has fbaConstraintVariables => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(FBAConstraintVariable)', metaclass => 'Typed', reader => '_fbaConstraintVariables', printOrder => '-1');


# LINKS:


# BUILDERS:


# CONSTANTS:
sub _type { return 'FBAConstraint'; }

my $attributes = [
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'name',
            'default' => '0',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'rhs',
            'default' => '0',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'sign',
            'default' => '0',
            'type' => 'Str',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {name => 0, rhs => 1, sign => 2};
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
            'name' => 'fbaConstraintVariables',
            'type' => 'encompassed',
            'class' => 'FBAConstraintVariable'
          }
        ];

my $subobject_map = {fbaConstraintVariables => 0};
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
around 'fbaConstraintVariables' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('fbaConstraintVariables');
};


__PACKAGE__->meta->make_immutable;
1;
