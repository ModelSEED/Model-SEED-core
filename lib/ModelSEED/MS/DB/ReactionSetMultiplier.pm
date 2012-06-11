########################################################################
# ModelSEED::MS::DB::ReactionSetMultiplier - This is the moose object corresponding to the ReactionSetMultiplier object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::ReactionSetMultiplier;
use ModelSEED::MS::IndexedObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::IndexedObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::GapfillingFormulation', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has reactionset_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', type => 'attribute', metaclass => 'Typed');
has reactionsetType => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has multiplierType => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has description => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has multiplier => (is => 'rw', isa => 'Num', printOrder => '-1', type => 'attribute', metaclass => 'Typed');


# LINKS:
has reactionset => (is => 'rw', isa => 'ModelSEED::MS::reactionsets', type => 'link(Biochemistry,reactionsets,reactionset_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildreactionset', weak_ref => 1);


# BUILDERS:
sub _buildreactionset {
  my ($self) = @_;
  return $self->getLinkedObject('Biochemistry','reactionsets',$self->reactionset_uuid());
}


# CONSTANTS:
sub _type { return 'ReactionSetMultiplier'; }

my $attributes = [
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'reactionset_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'reactionsetType',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'multiplierType',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'description',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'multiplier',
            'type' => 'Num',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {reactionset_uuid => 0, reactionsetType => 1, multiplierType => 2, description => 3, multiplier => 4};
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
