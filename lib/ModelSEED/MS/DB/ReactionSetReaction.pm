########################################################################
# ModelSEED::MS::DB::ReactionSetReaction - This is the moose object corresponding to the ReactionSetReaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::ReactionSetReaction;
use ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::ReactionSet', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has reaction_uuid => (is => 'rw', isa => 'ModelSEED::uuid', required => 1, type => 'attribute', metaclass => 'Typed');


# LINKS:
has reaction => (is => 'rw', isa => 'ModelSEED::MS::Reaction', type => 'link(Biochemistry,reactions,reaction_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildreaction', weak_ref => 1);


# BUILDERS:
sub _buildreaction {
  my ($self) = @_;
  return $self->getLinkedObject('Biochemistry','reactions',$self->reaction_uuid());
}


# CONSTANTS:
sub _type { return 'ReactionSetReaction'; }

my $attributes = [
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'reaction_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {reaction_uuid => 0};
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
