########################################################################
# ModelSEED::MS::DB::FBAMetaboliteProductionResult - This is the moose object corresponding to the FBAMetaboliteProductionResult object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::FBAMetaboliteProductionResult;
use ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::FBAResult', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has modelCompound_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');
has maximumProduction => (is => 'rw', isa => 'Num', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');


# LINKS:
has modelCompound => (is => 'rw', isa => 'ModelSEED::MS::ModelCompound', type => 'link(Model,modelcompounds,modelCompound_uuid)', metaclass => 'Typed', lazy => 1, builder => '_build_modelCompound', weak_ref => 1);


# BUILDERS:
sub _build_modelCompound {
  my ($self) = @_;
  return $self->getLinkedObject('Model','modelcompounds',$self->modelCompound_uuid());
}


# CONSTANTS:
sub _type { return 'FBAMetaboliteProductionResult'; }

my $attributes = [
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'modelCompound_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'maximumProduction',
            'type' => 'Num',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {modelCompound_uuid => 0, maximumProduction => 1};
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
