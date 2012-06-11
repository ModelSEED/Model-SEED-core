########################################################################
# ModelSEED::MS::DB::ModelAnalysisBiochemistry - This is the moose object corresponding to the ModelAnalysisBiochemistry object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::ModelAnalysisBiochemistry;
use ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::ModelAnalysis', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has biochemistry_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', type => 'attribute', metaclass => 'Typed');


# LINKS:
has biochemistry => (is => 'rw', isa => 'ModelSEED::MS::biochemistries', type => 'link(Store,biochemistries,biochemistry_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildbiochemistry', weak_ref => 1);


# BUILDERS:
sub _buildbiochemistry {
  my ($self) = @_;
  return $self->getLinkedObject('Store','biochemistries',$self->biochemistry_uuid());
}


# CONSTANTS:
sub _type { return 'ModelAnalysisBiochemistry'; }

my $attributes = [
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'biochemistry_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {biochemistry_uuid => 0};
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
