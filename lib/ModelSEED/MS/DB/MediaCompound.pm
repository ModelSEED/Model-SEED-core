########################################################################
# ModelSEED::MS::DB::MediaCompound - This is the moose object corresponding to the MediaCompound object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::MediaCompound;
use ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::Media', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has compound_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');
has concentration => (is => 'rw', isa => 'Num', printOrder => '0', default => '0.001', type => 'attribute', metaclass => 'Typed');
has maxFlux => (is => 'rw', isa => 'Num', printOrder => '0', default => '100', type => 'attribute', metaclass => 'Typed');
has minFlux => (is => 'rw', isa => 'Num', printOrder => '0', default => '-100', type => 'attribute', metaclass => 'Typed');


# LINKS:
has compound => (is => 'rw', isa => 'ModelSEED::MS::Compound', type => 'link(Biochemistry,compounds,compound_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildcompound', weak_ref => 1);


# BUILDERS:
sub _buildcompound {
  my ($self) = @_;
  return $self->getLinkedObject('Biochemistry','compounds',$self->compound_uuid());
}


# CONSTANTS:
sub _type { return 'MediaCompound'; }

my $attributes = [
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'compound_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'concentration',
            'default' => '0.001',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'maxFlux',
            'default' => '100',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'minFlux',
            'default' => '-100',
            'type' => 'Num',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {compound_uuid => 0, concentration => 1, maxFlux => 2, minFlux => 3};
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
