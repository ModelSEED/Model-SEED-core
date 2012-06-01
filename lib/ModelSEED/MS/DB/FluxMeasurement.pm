########################################################################
# ModelSEED::MS::DB::FluxMeasurement - This is the moose object corresponding to the FluxMeasurement object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::FluxMeasurement;
use ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::ExperimentDataPoint', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has value => (is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed');
has reacton_uuid => (is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed');
has compartment_uuid => (is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed');
has type => (is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed');


# LINKS:
has reaction => (is => 'rw', isa => 'ModelSEED::MS::Reaction', type => 'link(Biochemistry,reactions,reacton_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildreaction', weak_ref => 1);
has compartment => (is => 'rw', isa => 'ModelSEED::MS::Compartment', type => 'link(Biochemistry,compartments,compartment_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildcompartment', weak_ref => 1);


# BUILDERS:
sub _buildreaction {
  my ($self) = @_;
  return $self->getLinkedObject('Biochemistry','reactions',$self->reacton_uuid());
}
sub _buildcompartment {
  my ($self) = @_;
  return $self->getLinkedObject('Biochemistry','compartments',$self->compartment_uuid());
}


# CONSTANTS:
sub _type { return 'FluxMeasurement'; }

my $attributes = [
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'value',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'reacton_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'compartment_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'type',
            'type' => 'Str',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {value => 0, reacton_uuid => 1, compartment_uuid => 2, type => 3};
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
