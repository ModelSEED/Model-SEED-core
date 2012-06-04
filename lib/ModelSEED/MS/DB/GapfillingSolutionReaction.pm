########################################################################
# ModelSEED::MS::DB::GapfillingSolutionReaction - This is the moose object corresponding to the GapfillingSolutionReaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::GapfillingSolutionReaction;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::GfSolutionReactionGeneCandidate;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::GapfillingSolution', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has modelreaction_uuid => (is => 'rw', isa => 'ModelSEED::uuid', required => 1, type => 'attribute', metaclass => 'Typed');
has direction => (is => 'rw', isa => 'Str', default => '1', type => 'attribute', metaclass => 'Typed');


# SUBOBJECTS:
has gfSolutionReactionGeneCandidates => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(GfSolutionReactionGeneCandidate)', metaclass => 'Typed', reader => '_gfSolutionReactionGeneCandidates');


# LINKS:
has modelreaction => (is => 'rw', isa => 'ModelSEED::MS::ModelReaction', type => 'link(Model,modelreactions,modelreaction_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildmodelreaction', weak_ref => 1);


# BUILDERS:
sub _buildmodelreaction {
  my ($self) = @_;
  return $self->getLinkedObject('Model','modelreactions',$self->modelreaction_uuid());
}


# CONSTANTS:
sub _type { return 'GapfillingSolutionReaction'; }

my $attributes = [
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'modelreaction_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'direction',
            'default' => '1',
            'type' => 'Str',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {modelreaction_uuid => 0, direction => 1};
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
            'name' => 'gfSolutionReactionGeneCandidates',
            'type' => 'encompassed',
            'class' => 'GfSolutionReactionGeneCandidate'
          }
        ];

my $subobject_map = {gfSolutionReactionGeneCandidates => 0};
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
around 'gfSolutionReactionGeneCandidates' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('gfSolutionReactionGeneCandidates');
};


__PACKAGE__->meta->make_immutable;
1;
