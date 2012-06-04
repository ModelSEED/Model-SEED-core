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
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::IndexedObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::FBAFormulation', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', lazy => 1, builder => '_builduuid', type => 'attribute', metaclass => 'Typed');
has name => (is => 'rw', isa => 'ModelSEED::varchar', required => 1, default => '', type => 'attribute', metaclass => 'Typed');
has modDate => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildmodDate', type => 'attribute', metaclass => 'Typed');
has fbaformulation_uuid => (is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed');
has resultNotes => (is => 'rw', isa => 'Str', required => 1, default => '', type => 'attribute', metaclass => 'Typed');
has objectiveValue => (is => 'rw', isa => 'Num', required => 1, default => '', type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has fbaCompoundVariables => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(FBACompoundVariable)', metaclass => 'Typed', reader => '_fbaCompoundVariables');
has fbaReactionVariables => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(FBAReactionVariable)', metaclass => 'Typed', reader => '_fbaReactionVariables');
has fbaBiomassVariables => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(FBABiomassVariable)', metaclass => 'Typed', reader => '_fbaBiomassVariables');


# LINKS:
has fbaformulation => (is => 'rw', isa => 'ModelSEED::MS::fbaformulations', type => 'link(ModelAnalysis,fbaformulations,fbaformulation_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildfbaformulation', weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }
sub _buildfbaformulation {
  my ($self) = @_;
  return $self->getLinkedObject('ModelAnalysis','fbaformulations',$self->fbaformulation_uuid());
}


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
            'req' => 1,
            'printOrder' => 1,
            'name' => 'name',
            'default' => '',
            'type' => 'ModelSEED::varchar',
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
            'printOrder' => 0,
            'name' => 'fbaformulation_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 3,
            'name' => 'resultNotes',
            'default' => '',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 2,
            'name' => 'objectiveValue',
            'default' => '',
            'type' => 'Num',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, name => 1, modDate => 2, fbaformulation_uuid => 3, resultNotes => 4, objectiveValue => 5};
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
          }
        ];

my $subobject_map = {fbaCompoundVariables => 0, fbaReactionVariables => 1, fbaBiomassVariables => 2};
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


__PACKAGE__->meta->make_immutable;
1;
