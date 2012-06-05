########################################################################
# ModelSEED::MS::DB::ModelReactionProteinSubunit - This is the moose object corresponding to the ModelReactionProteinSubunit object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::ModelReactionProteinSubunit;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::ModelReactionProteinSubunitGene;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::ModelReactionProtein', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has role_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');
has triggering => (is => 'rw', isa => 'Bool', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has optional => (is => 'rw', isa => 'Bool', printOrder => '0', default => '0', type => 'attribute', metaclass => 'Typed');
has note => (is => 'rw', isa => 'Str', printOrder => '0', default => '', type => 'attribute', metaclass => 'Typed');


# SUBOBJECTS:
has modelReactionProteinSubunitGenes => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(ModelReactionProteinSubunitGene)', metaclass => 'Typed', reader => '_modelReactionProteinSubunitGenes', printOrder => '-1');


# LINKS:
has role => (is => 'rw', isa => 'ModelSEED::MS::Role', type => 'link(Mapping,roles,role_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildrole', weak_ref => 1);


# BUILDERS:
sub _buildrole {
  my ($self) = @_;
  return $self->getLinkedObject('Mapping','roles',$self->role_uuid());
}


# CONSTANTS:
sub _type { return 'ModelReactionProteinSubunit'; }

my $attributes = [
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'role_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'triggering',
            'default' => '1',
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'optional',
            'default' => '0',
            'type' => 'Bool',
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

my $attribute_map = {role_uuid => 0, triggering => 1, optional => 2, note => 3};
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
            'name' => 'modelReactionProteinSubunitGenes',
            'type' => 'encompassed',
            'class' => 'ModelReactionProteinSubunitGene'
          }
        ];

my $subobject_map = {modelReactionProteinSubunitGenes => 0};
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
around 'modelReactionProteinSubunitGenes' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('modelReactionProteinSubunitGenes');
};


__PACKAGE__->meta->make_immutable;
1;
