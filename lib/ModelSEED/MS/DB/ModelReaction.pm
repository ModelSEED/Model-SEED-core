########################################################################
# ModelSEED::MS::DB::ModelReaction - This is the moose object corresponding to the ModelReaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::ModelReaction;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::ModelReactionProtein;
use ModelSEED::MS::ModelReactionReagent;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::Model', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', lazy => 1, builder => '_build_uuid', type => 'attribute', metaclass => 'Typed');
has modDate => (is => 'rw', isa => 'Str', printOrder => '-1', lazy => 1, builder => '_build_modDate', type => 'attribute', metaclass => 'Typed');
has reactioninstance_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '-1', required => 1, type => 'attribute', metaclass => 'Typed');
has direction => (is => 'rw', isa => 'Str', printOrder => '-1', default => '=', type => 'attribute', metaclass => 'Typed');
has protons => (is => 'rw', isa => 'Num', printOrder => '-1', default => '0', type => 'attribute', metaclass => 'Typed');
has modelcompartment_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '-1', required => 1, type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has modelReactionProteins => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(ModelReactionProtein)', metaclass => 'Typed', reader => '_modelReactionProteins', printOrder => '-1');
has modelReactionReagents => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(ModelReactionReagent)', metaclass => 'Typed', reader => '_modelReactionReagents', printOrder => '-1');


# LINKS:
has reactioninstance => (is => 'rw', isa => 'ModelSEED::MS::ReactionInstance', type => 'link(Biochemistry,reactioninstances,reactioninstance_uuid)', metaclass => 'Typed', lazy => 1, builder => '_build_reactioninstance', weak_ref => 1);
has modelcompartment => (is => 'rw', isa => 'ModelSEED::MS::ModelCompartment', type => 'link(Model,modelcompartments,modelcompartment_uuid)', metaclass => 'Typed', lazy => 1, builder => '_build_modelcompartment', weak_ref => 1);


# BUILDERS:
sub _build_uuid { return Data::UUID->new()->create_str(); }
sub _build_modDate { return DateTime->now()->datetime(); }
sub _build_reactioninstance {
  my ($self) = @_;
  return $self->getLinkedObject('Biochemistry','reactioninstances',$self->reactioninstance_uuid());
}
sub _build_modelcompartment {
  my ($self) = @_;
  return $self->getLinkedObject('Model','modelcompartments',$self->modelcompartment_uuid());
}


# CONSTANTS:
sub _type { return 'ModelReaction'; }

my $attributes = [
          {
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
            'req' => 1,
            'printOrder' => -1,
            'name' => 'reactioninstance_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'len' => 1,
            'req' => 0,
            'printOrder' => -1,
            'name' => 'direction',
            'default' => '=',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'protons',
            'default' => 0,
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => -1,
            'name' => 'modelcompartment_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, modDate => 1, reactioninstance_uuid => 2, direction => 3, protons => 4, modelcompartment_uuid => 5};
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
            'name' => 'modelReactionProteins',
            'type' => 'encompassed',
            'class' => 'ModelReactionProtein'
          },
          {
            'printOrder' => -1,
            'name' => 'modelReactionReagents',
            'type' => 'encompassed',
            'class' => 'ModelReactionReagent'
          }
        ];

my $subobject_map = {modelReactionProteins => 0, modelReactionReagents => 1};
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
around 'modelReactionProteins' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('modelReactionProteins');
};
around 'modelReactionReagents' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('modelReactionReagents');
};


__PACKAGE__->meta->make_immutable;
1;
