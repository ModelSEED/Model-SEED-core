########################################################################
# ModelSEED::MS::DB::ReactionCue - This is the moose object corresponding to the ReactionCue object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::ReactionCue;
use ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::Reaction', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has cue_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');
has count => (is => 'rw', isa => 'Num', printOrder => '0', default => '', type => 'attribute', metaclass => 'Typed');


# LINKS:
has cue => (is => 'rw', isa => 'ModelSEED::MS::Cue', type => 'link(Biochemistry,cues,cue_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildcue', weak_ref => 1);


# BUILDERS:
sub _buildcue {
  my ($self) = @_;
  return $self->getLinkedObject('Biochemistry','cues',$self->cue_uuid());
}


# CONSTANTS:
sub _type { return 'ReactionCue'; }

my $attributes = [
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'cue_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'count',
            'default' => '',
            'type' => 'Num',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {cue_uuid => 0, count => 1};
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
