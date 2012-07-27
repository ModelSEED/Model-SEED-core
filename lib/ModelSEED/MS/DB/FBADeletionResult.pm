########################################################################
# ModelSEED::MS::DB::FBADeletionResult - This is the moose object corresponding to the FBADeletionResult object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::FBADeletionResult;
use ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::FBAResult', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has geneko_uuids => (is => 'rw', isa => 'ArrayRef', printOrder => '-1', required => 1, type => 'attribute', metaclass => 'Typed');
has growthFraction => (is => 'rw', isa => 'Num', printOrder => '1', required => 1, type => 'attribute', metaclass => 'Typed');


# LINKS:
has genekos => (is => 'rw', isa => 'ArrayRef[ModelSEED::MS::Feature]', type => 'link(Annotation,features,geneko_uuids)', metaclass => 'Typed', lazy => 1, builder => '_build_genekos');


# BUILDERS:
sub _build_genekos {
  my ($self) = @_;
  return $self->getLinkedObjectArray('Annotation','features',$self->geneko_uuids());
}


# CONSTANTS:
sub _type { return 'FBADeletionResult'; }

my $attributes = [
          {
            'req' => 1,
            'printOrder' => -1,
            'name' => 'geneko_uuids',
            'type' => 'ArrayRef',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 1,
            'name' => 'growthFraction',
            'type' => 'Num',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {geneko_uuids => 0, growthFraction => 1};
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
