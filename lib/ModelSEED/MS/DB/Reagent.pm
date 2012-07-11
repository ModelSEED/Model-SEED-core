########################################################################
# ModelSEED::MS::DB::Reagent - This is the moose object corresponding to the Reagent object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Reagent;
use ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::Reaction', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has compound_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');
has destinationCompartment_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');
has coefficient => (is => 'rw', isa => 'Num', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');
has isTransport => (is => 'rw', isa => 'Bool', printOrder => '0', default => '0', type => 'attribute', metaclass => 'Typed');
has isCofactor => (is => 'rw', isa => 'Bool', printOrder => '0', default => '0', type => 'attribute', metaclass => 'Typed');


# LINKS:
has compound => (is => 'rw', isa => 'ModelSEED::MS::Compound', type => 'link(Biochemistry,compounds,compound_uuid)', metaclass => 'Typed', lazy => 1, builder => '_build_compound', weak_ref => 1);
has destinationCompartment => (is => 'rw', isa => 'ModelSEED::MS::Compartment', type => 'link(Biochemistry,compartments,destinationCompartment_uuid)', metaclass => 'Typed', lazy => 1, builder => '_build_destinationCompartment', weak_ref => 1);


# BUILDERS:
sub _build_compound {
  my ($self) = @_;
  return $self->getLinkedObject('Biochemistry','compounds',$self->compound_uuid());
}
sub _build_destinationCompartment {
  my ($self) = @_;
  return $self->getLinkedObject('Biochemistry','compartments',$self->destinationCompartment_uuid());
}


# CONSTANTS:
sub _type { return 'Reagent'; }

my $attributes = [
          {
            'len' => 36,
            'req' => 1,
            'printOrder' => 0,
            'name' => 'compound_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'len' => 36,
            'req' => 1,
            'printOrder' => 0,
            'name' => 'destinationCompartment_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'coefficient',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'printOrder' => 0,
            'name' => 'isTransport',
            'default' => '0',
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'isCofactor',
            'default' => '0',
            'type' => 'Bool',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {compound_uuid => 0, destinationCompartment_uuid => 1, coefficient => 2, isTransport => 3, isCofactor => 4};
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
