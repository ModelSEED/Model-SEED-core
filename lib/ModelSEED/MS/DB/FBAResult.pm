########################################################################
# ModelSEED::MS::DB::FBAResult - This is the moose object corresponding to the FBAResult object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::FBAResult;
use ModelSEED::MS::IndexedObject;
use ModelSEED::MS::FBACompoundVariable;
use ModelSEED::MS::FBAReactionVariable;
use ModelSEED::MS::FBABiomassVariable;
use ModelSEED::MS::FBAPhenotypeSimultationResult;
use ModelSEED::MS::FBADeletionResult;
use ModelSEED::MS::FBAMinimalMediaResult;
use ModelSEED::MS::FBAMetaboliteProductionResult;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::IndexedObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::FBAFormulation', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', lazy => 1, builder => '_build_uuid', type => 'attribute', metaclass => 'Typed');
has modDate => (is => 'rw', isa => 'Str', printOrder => '-1', lazy => 1, builder => '_build_modDate', type => 'attribute', metaclass => 'Typed');
has notes => (is => 'rw', isa => 'Str', printOrder => '3', default => '', type => 'attribute', metaclass => 'Typed');
has objectiveValue => (is => 'rw', isa => 'Num', printOrder => '2', type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has fbaCompoundVariables => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(FBACompoundVariable)', metaclass => 'Typed', reader => '_fbaCompoundVariables', printOrder => '2');
has fbaReactionVariables => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(FBAReactionVariable)', metaclass => 'Typed', reader => '_fbaReactionVariables', printOrder => '1');
has fbaBiomassVariables => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(FBABiomassVariable)', metaclass => 'Typed', reader => '_fbaBiomassVariables', printOrder => '0');
has fbaPhenotypeSimultationResults => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(FBAPhenotypeSimultationResult)', metaclass => 'Typed', reader => '_fbaPhenotypeSimultationResults', printOrder => '0');
has fbaDeletionResults => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(FBADeletionResult)', metaclass => 'Typed', reader => '_fbaDeletionResults', printOrder => '0');
has minimalMediaResults => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(FBAMinimalMediaResult)', metaclass => 'Typed', reader => '_minimalMediaResults', printOrder => '0');
has fbaMetaboliteProductionResults => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(FBAMetaboliteProductionResult)', metaclass => 'Typed', reader => '_fbaMetaboliteProductionResults', printOrder => '0');


# LINKS:


# BUILDERS:
sub _build_uuid { return Data::UUID->new()->create_str(); }
sub _build_modDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'FBAResult'; }

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
            'req' => 0,
            'printOrder' => 3,
            'name' => 'notes',
            'default' => '',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 2,
            'name' => 'objectiveValue',
            'type' => 'Num',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, modDate => 1, notes => 2, objectiveValue => 3};
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
            'printOrder' => 2,
            'name' => 'fbaCompoundVariables',
            'type' => 'encompassed',
            'class' => 'FBACompoundVariable'
          },
          {
            'printOrder' => 1,
            'name' => 'fbaReactionVariables',
            'type' => 'encompassed',
            'class' => 'FBAReactionVariable'
          },
          {
            'printOrder' => 0,
            'name' => 'fbaBiomassVariables',
            'type' => 'encompassed',
            'class' => 'FBABiomassVariable'
          },
          {
            'printOrder' => 0,
            'name' => 'fbaPhenotypeSimultationResults',
            'type' => 'encompassed',
            'class' => 'FBAPhenotypeSimultationResult'
          },
          {
            'printOrder' => 0,
            'name' => 'fbaDeletionResults',
            'type' => 'encompassed',
            'class' => 'FBADeletionResult'
          },
          {
            'printOrder' => 0,
            'name' => 'minimalMediaResults',
            'type' => 'encompassed',
            'class' => 'FBAMinimalMediaResult'
          },
          {
            'printOrder' => 0,
            'name' => 'fbaMetaboliteProductionResults',
            'type' => 'encompassed',
            'class' => 'FBAMetaboliteProductionResult'
          }
        ];

my $subobject_map = {fbaCompoundVariables => 0, fbaReactionVariables => 1, fbaBiomassVariables => 2, fbaPhenotypeSimultationResults => 3, fbaDeletionResults => 4, minimalMediaResults => 5, fbaMetaboliteProductionResults => 6};
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
around 'fbaCompoundVariables' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('fbaCompoundVariables');
};
around 'fbaReactionVariables' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('fbaReactionVariables');
};
around 'fbaBiomassVariables' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('fbaBiomassVariables');
};
around 'fbaPhenotypeSimultationResults' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('fbaPhenotypeSimultationResults');
};
around 'fbaDeletionResults' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('fbaDeletionResults');
};
around 'minimalMediaResults' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('minimalMediaResults');
};
around 'fbaMetaboliteProductionResults' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('fbaMetaboliteProductionResults');
};


__PACKAGE__->meta->make_immutable;
1;
