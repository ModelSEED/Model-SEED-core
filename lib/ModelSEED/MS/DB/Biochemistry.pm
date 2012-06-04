########################################################################
# ModelSEED::MS::DB::Biochemistry - This is the moose object corresponding to the Biochemistry object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Biochemistry;
use ModelSEED::MS::IndexedObject;
use ModelSEED::MS::Compartment;
use ModelSEED::MS::Compound;
use ModelSEED::MS::Reaction;
use ModelSEED::MS::ReactionInstance;
use ModelSEED::MS::Media;
use ModelSEED::MS::CompoundSet;
use ModelSEED::MS::ReactionSet;
use ModelSEED::MS::AliasSet;
use ModelSEED::MS::Cue;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::IndexedObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::Store', type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', lazy => 1, builder => '_builduuid', type => 'attribute', metaclass => 'Typed');
has defaultNameSpace => (is => 'rw', isa => 'Str', default => 'ModelSEED', type => 'attribute', metaclass => 'Typed');
has modDate => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildmodDate', type => 'attribute', metaclass => 'Typed');
has locked => (is => 'rw', isa => 'Bool', default => '1', type => 'attribute', metaclass => 'Typed');
has public => (is => 'rw', isa => 'Bool', default => '0', type => 'attribute', metaclass => 'Typed');
has name => (is => 'rw', isa => 'ModelSEED::varchar', default => '', type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has compartments => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(Compartment)', metaclass => 'Typed', reader => '_compartments');
has compounds => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(Compound)', metaclass => 'Typed', reader => '_compounds');
has reactions => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(Reaction)', metaclass => 'Typed', reader => '_reactions');
has reactioninstances => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(ReactionInstance)', metaclass => 'Typed', reader => '_reactioninstances');
has media => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(Media)', metaclass => 'Typed', reader => '_media');
has compoundSets => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(CompoundSet)', metaclass => 'Typed', reader => '_compoundSets');
has reactionSets => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(ReactionSet)', metaclass => 'Typed', reader => '_reactionSets');
has aliasSets => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(AliasSet)', metaclass => 'Typed', reader => '_aliasSets');
has cues => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(Cue)', metaclass => 'Typed', reader => '_cues');


# LINKS:


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Biochemistry'; }

my $attributes = [
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'len' => 32,
            'req' => 0,
            'printOrder' => 2,
            'name' => 'defaultNameSpace',
            'default' => 'ModelSEED',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'modDate',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'locked',
            'default' => '1',
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'public',
            'default' => '0',
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 1,
            'name' => 'name',
            'default' => '',
            'type' => 'ModelSEED::varchar',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, defaultNameSpace => 1, modDate => 2, locked => 3, public => 4, name => 5};
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
            'printOrder' => 0,
            'name' => 'compartments',
            'type' => 'child',
            'class' => 'Compartment'
          },
          {
            'printOrder' => 3,
            'name' => 'compounds',
            'type' => 'child',
            'class' => 'Compound'
          },
          {
            'printOrder' => 4,
            'name' => 'reactions',
            'type' => 'child',
            'class' => 'Reaction'
          },
          {
            'printOrder' => 5,
            'name' => 'reactioninstances',
            'type' => 'child',
            'class' => 'ReactionInstance'
          },
          {
            'printOrder' => 2,
            'name' => 'media',
            'type' => 'child',
            'class' => 'Media'
          },
          {
            'name' => 'compoundSets',
            'type' => 'child',
            'class' => 'CompoundSet'
          },
          {
            'name' => 'reactionSets',
            'type' => 'child',
            'class' => 'ReactionSet'
          },
          {
            'name' => 'aliasSets',
            'type' => 'child',
            'class' => 'AliasSet'
          },
          {
            'printOrder' => 1,
            'name' => 'cues',
            'type' => 'encompassed',
            'class' => 'Cue'
          }
        ];

my $subobject_map = {compartments => 0, compounds => 1, reactions => 2, reactioninstances => 3, media => 4, compoundSets => 5, reactionSets => 6, aliasSets => 7, cues => 8};
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
around 'compartments' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('compartments');
};
around 'compounds' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('compounds');
};
around 'reactions' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('reactions');
};
around 'reactioninstances' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('reactioninstances');
};
around 'media' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('media');
};
around 'compoundSets' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('compoundSets');
};
around 'reactionSets' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('reactionSets');
};
around 'aliasSets' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('aliasSets');
};
around 'cues' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('cues');
};


__PACKAGE__->meta->make_immutable;
1;
