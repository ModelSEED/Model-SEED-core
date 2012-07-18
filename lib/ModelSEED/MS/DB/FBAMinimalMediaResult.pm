########################################################################
# ModelSEED::MS::DB::FBAMinimalMediaResult - This is the moose object corresponding to the FBAMinimalMediaResult object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::FBAMinimalMediaResult;
use ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::FBAResult', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has minimalMedia_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');
has essentialNutrient_uuids => (is => 'rw', isa => 'ArrayRef', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');
has optionalNutrient_uuids => (is => 'rw', isa => 'ArrayRef', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');


# LINKS:
has minimalMedia => (is => 'rw', isa => 'ModelSEED::MS::Media', type => 'link(Biochemistry,media,minimalMedia_uuid)', metaclass => 'Typed', lazy => 1, builder => '_build_minimalMedia', weak_ref => 1);
has essentialNutrients => (is => 'rw', isa => 'ArrayRef[ModelSEED::MS::Compound]', type => 'link(Biochemistry,compounds,essentialNutrient_uuids)', metaclass => 'Typed', lazy => 1, builder => '_build_essentialNutrients');
has optionalNutrients => (is => 'rw', isa => 'ArrayRef[ModelSEED::MS::Compound]', type => 'link(Biochemistry,compounds,optionalNutrient_uuids)', metaclass => 'Typed', lazy => 1, builder => '_build_optionalNutrients');


# BUILDERS:
sub _build_minimalMedia {
  my ($self) = @_;
  return $self->getLinkedObject('Biochemistry','media',$self->minimalMedia_uuid());
}
sub _build_essentialNutrients {
  my ($self) = @_;
  return $self->getLinkedObjectArray('Biochemistry','compounds',$self->essentialNutrient_uuids());
}
sub _build_optionalNutrients {
  my ($self) = @_;
  return $self->getLinkedObjectArray('Biochemistry','compounds',$self->optionalNutrient_uuids());
}


# CONSTANTS:
sub _type { return 'FBAMinimalMediaResult'; }

my $attributes = [
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'minimalMedia_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'essentialNutrient_uuids',
            'type' => 'ArrayRef',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'optionalNutrient_uuids',
            'type' => 'ArrayRef',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {minimalMedia_uuid => 0, essentialNutrient_uuids => 1, optionalNutrient_uuids => 2};
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
