########################################################################
# ModelSEED::MS::DB::ModelReactionProtein - This is the moose object corresponding to the ModelReactionProtein object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::ModelReactionProtein;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::ModelReactionProteinSubunit;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::ModelReaction', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has complex_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');
has note => (is => 'rw', isa => 'Str', printOrder => '0', default => '', type => 'attribute', metaclass => 'Typed');


# SUBOBJECTS:
has modelReactionProteinSubunits => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(ModelReactionProteinSubunit)', metaclass => 'Typed', reader => '_modelReactionProteinSubunits', printOrder => '-1');


# LINKS:
has complex => (is => 'rw', isa => 'ModelSEED::MS::Complex', type => 'link(Mapping,complexes,complex_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildcomplex', weak_ref => 1);


# BUILDERS:
sub _buildcomplex {
  my ($self) = @_;
  return $self->getLinkedObject('Mapping','complexes',$self->complex_uuid());
}


# CONSTANTS:
sub _type { return 'ModelReactionProtein'; }

my $attributes = [
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'complex_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'note',
            'default' => '',
            'type' => 'Str',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {complex_uuid => 0, note => 1};
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
            'name' => 'modelReactionProteinSubunits',
            'type' => 'encompassed',
            'class' => 'ModelReactionProteinSubunit'
          }
        ];

my $subobject_map = {modelReactionProteinSubunits => 0};
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
around 'modelReactionProteinSubunits' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('modelReactionProteinSubunits');
};


__PACKAGE__->meta->make_immutable;
1;
