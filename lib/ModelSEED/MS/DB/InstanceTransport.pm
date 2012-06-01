########################################################################
# ModelSEED::MS::DB::InstanceTransport - This is the moose object corresponding to the InstanceTransport object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::InstanceTransport;
use ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::ReactionInstance', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has compound_uuid => (is => 'rw', isa => 'ModelSEED::uuid', required => 1, type => 'attribute', metaclass => 'Typed');
has compartment_uuid => (is => 'rw', isa => 'ModelSEED::uuid', required => 1, type => 'attribute', metaclass => 'Typed');
has compartmentIndex => (is => 'rw', isa => 'Int', required => 1, type => 'attribute', metaclass => 'Typed');
has coefficient => (is => 'rw', isa => 'Num', required => 1, type => 'attribute', metaclass => 'Typed');


# LINKS:
has compound => (is => 'rw', isa => 'ModelSEED::MS::Compound', type => 'link(Biochemistry,compounds,compound_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildcompound', weak_ref => 1);
has compartment => (is => 'rw', isa => 'ModelSEED::MS::Compartment', type => 'link(Biochemistry,compartments,compartment_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildcompartment', weak_ref => 1);


# BUILDERS:
sub _buildcompound {
  my ($self) = @_;
  return $self->getLinkedObject('Biochemistry','compounds',$self->compound_uuid());
}
sub _buildcompartment {
  my ($self) = @_;
  return $self->getLinkedObject('Biochemistry','compartments',$self->compartment_uuid());
}


# CONSTANTS:
sub _type { return 'InstanceTransport'; }

my $attributes = [
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'compound_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'compartment_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'compartmentIndex',
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'coefficient',
            'type' => 'Num',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {compound_uuid => 0, compartment_uuid => 1, compartmentIndex => 2, coefficient => 3};
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
