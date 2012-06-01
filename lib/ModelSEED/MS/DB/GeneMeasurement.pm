########################################################################
# ModelSEED::MS::DB::GeneMeasurement - This is the moose object corresponding to the GeneMeasurement object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::GeneMeasurement;
use ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::ExperimentDataPoint', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has value => (is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed');
has feature_uuid => (is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed');
has method => (is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed');


# LINKS:
has feature => (is => 'rw', isa => 'ModelSEED::MS::features', type => 'link(Genome,features,feature_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildfeature', weak_ref => 1);


# BUILDERS:
sub _buildfeature {
  my ($self) = @_;
  return $self->getLinkedObject('Genome','features',$self->feature_uuid());
}


# CONSTANTS:
sub _type { return 'GeneMeasurement'; }

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
            'name' => 'feature_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'method',
            'type' => 'Str',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {value => 0, feature_uuid => 1, method => 2};
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
