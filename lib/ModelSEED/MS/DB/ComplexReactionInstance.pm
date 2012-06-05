########################################################################
# ModelSEED::MS::DB::ComplexReactionInstance - This is the moose object corresponding to the ComplexReactionInstance object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::ComplexReactionInstance;
use ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::Complex', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has reactioninstance_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');
has compartment => (is => 'rw', isa => 'Str', printOrder => '0', default => 'cytosol', type => 'attribute', metaclass => 'Typed');


# LINKS:
has reactioninstance => (is => 'rw', isa => 'ModelSEED::MS::ReactionInstance', type => 'link(Biochemistry,reactioninstances,reactioninstance_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildreactioninstance', weak_ref => 1);


# BUILDERS:
sub _buildreactioninstance {
  my ($self) = @_;
  return $self->getLinkedObject('Biochemistry','reactioninstances',$self->reactioninstance_uuid());
}


# CONSTANTS:
sub _type { return 'ComplexReactionInstance'; }

my $attributes = [
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'reactioninstance_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'compartment',
            'default' => 'cytosol',
            'type' => 'Str',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {reactioninstance_uuid => 0, compartment => 1};
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
