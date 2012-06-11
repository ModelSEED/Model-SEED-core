########################################################################
# ModelSEED::MS::DB::Reaction - This is the moose object corresponding to the Reaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Reaction;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::ReactionCue;
use ModelSEED::MS::ReactionReactionInstance;
use ModelSEED::MS::Reagent;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::Biochemistry', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', lazy => 1, builder => '_builduuid', type => 'attribute', metaclass => 'Typed');
has modDate => (is => 'rw', isa => 'Str', printOrder => '-1', lazy => 1, builder => '_buildmodDate', type => 'attribute', metaclass => 'Typed');
has locked => (is => 'rw', isa => 'Int', printOrder => '-1', default => '0', type => 'attribute', metaclass => 'Typed');
has name => (is => 'rw', isa => 'ModelSEED::varchar', printOrder => '1', default => '', type => 'attribute', metaclass => 'Typed');
has abbreviation => (is => 'rw', isa => 'ModelSEED::varchar', printOrder => '2', default => '', type => 'attribute', metaclass => 'Typed');
has cksum => (is => 'rw', isa => 'ModelSEED::varchar', printOrder => '-1', default => '', type => 'attribute', metaclass => 'Typed');
has deltaG => (is => 'rw', isa => 'Num', printOrder => '8', type => 'attribute', metaclass => 'Typed');
has deltaGErr => (is => 'rw', isa => 'Num', printOrder => '9', type => 'attribute', metaclass => 'Typed');
has reversibility => (is => 'rw', isa => 'Str', printOrder => '5', default => '=', type => 'attribute', metaclass => 'Typed');
has thermoReversibility => (is => 'rw', isa => 'Str', printOrder => '6', type => 'attribute', metaclass => 'Typed');
has defaultProtons => (is => 'rw', isa => 'Num', printOrder => '7', type => 'attribute', metaclass => 'Typed');
has status => (is => 'rw', isa => 'Str', printOrder => '10', type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has reactionCues => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(ReactionCue)', metaclass => 'Typed', reader => '_reactionCues', printOrder => '-1');
has reactionreactioninstances => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(ReactionReactionInstance)', metaclass => 'Typed', reader => '_reactionreactioninstances', printOrder => '-1');
has reagents => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(Reagent)', metaclass => 'Typed', reader => '_reagents', printOrder => '-1');


# LINKS:
has id => (is => 'rw', lazy => 1, builder => '_buildid', isa => 'Str', type => 'id', metaclass => 'Typed');


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Reaction'; }

my $attributes = [
          {
            'len' => 36,
            'req' => 0,
            'printOrder' => 0,
            'name' => 'uuid',
            'type' => 'ModelSEED::uuid',
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
            'default' => '0',
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 1,
            'name' => 'name',
            'default' => '',
            'type' => 'ModelSEED::varchar',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 2,
            'name' => 'abbreviation',
            'default' => '',
            'type' => 'ModelSEED::varchar',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'cksum',
            'default' => '',
            'type' => 'ModelSEED::varchar',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 8,
            'name' => 'deltaG',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 9,
            'name' => 'deltaGErr',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'len' => 1,
            'req' => 0,
            'printOrder' => 5,
            'name' => 'reversibility',
            'default' => '=',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'len' => 1,
            'req' => 0,
            'printOrder' => 6,
            'name' => 'thermoReversibility',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 7,
            'name' => 'defaultProtons',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 10,
            'name' => 'status',
            'type' => 'Str',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, modDate => 1, locked => 2, name => 3, abbreviation => 4, cksum => 5, deltaG => 6, deltaGErr => 7, reversibility => 8, thermoReversibility => 9, defaultProtons => 10, status => 11};
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
            'name' => 'reactionCues',
            'type' => 'encompassed',
            'class' => 'ReactionCue'
          },
          {
            'printOrder' => -1,
            'name' => 'reactionreactioninstances',
            'type' => 'encompassed',
            'class' => 'ReactionReactionInstance'
          },
          {
            'printOrder' => -1,
            'name' => 'reagents',
            'type' => 'encompassed',
            'class' => 'Reagent'
          }
        ];

my $subobject_map = {reactionCues => 0, reactionreactioninstances => 1, reagents => 2};
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
sub _aliasowner { return 'Biochemistry'; }


# SUBOBJECT READERS:
around 'reactionCues' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('reactionCues');
};
around 'reactionreactioninstances' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('reactionreactioninstances');
};
around 'reagents' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('reagents');
};


__PACKAGE__->meta->make_immutable;
1;
