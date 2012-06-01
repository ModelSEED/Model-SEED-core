########################################################################
# ModelSEED::MS::DB::ModelAnalysis - This is the moose object corresponding to the ModelAnalysis object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::ModelAnalysis;
use ModelSEED::MS::IndexedObject;
use ModelSEED::MS::ModelAnalysisModel;
use ModelSEED::MS::ModelAnalysisMapping;
use ModelSEED::MS::ModelAnalysisBiochemistry;
use ModelSEED::MS::ModelAnalysisAnnotation;
use ModelSEED::MS::FBAFormulation;
use ModelSEED::MS::GapfillingFormulation;
use ModelSEED::MS::FBAProblem;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::IndexedObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::Store', type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', lazy => 1, builder => '_builduuid', type => 'attribute', metaclass => 'Typed');
has defaultNameSpace => (is => 'rw', isa => 'Str', default => 'ModelSEED', type => 'attribute', metaclass => 'Typed');
has modDate => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildmodDate', type => 'attribute', metaclass => 'Typed');
has locked => (is => 'rw', isa => 'Int', default => '0', type => 'attribute', metaclass => 'Typed');
has public => (is => 'rw', isa => 'Int', default => '0', type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has modelAnalysisModels => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(ModelAnalysisModel)', metaclass => 'Typed', reader => '_modelAnalysisModels');
has modelAnalysisMappings => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(ModelAnalysisMapping)', metaclass => 'Typed', reader => '_modelAnalysisMappings');
has modelAnalysisBiochemistries => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(ModelAnalysisBiochemistry)', metaclass => 'Typed', reader => '_modelAnalysisBiochemistries');
has modelAnalysisAnnotations => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(ModelAnalysisAnnotation)', metaclass => 'Typed', reader => '_modelAnalysisAnnotations');
has fbaFormulations => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(FBAFormulation)', metaclass => 'Typed', reader => '_fbaFormulations');
has gapfillingFormulations => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(GapfillingFormulation)', metaclass => 'Typed', reader => '_gapfillingFormulations');
has fbaProblems => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(FBAProblem)', metaclass => 'Typed', reader => '_fbaProblems');


# LINKS:


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'ModelAnalysis'; }

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
            'printOrder' => 3,
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
            'default' => '0',
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'public',
            'default' => '0',
            'type' => 'Int',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, defaultNameSpace => 1, modDate => 2, locked => 3, public => 4};
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
            'name' => 'modelAnalysisModels',
            'type' => 'child',
            'class' => 'ModelAnalysisModel'
          },
          {
            'printOrder' => 0,
            'name' => 'modelAnalysisMappings',
            'type' => 'child',
            'class' => 'ModelAnalysisMapping'
          },
          {
            'printOrder' => 0,
            'name' => 'modelAnalysisBiochemistries',
            'type' => 'child',
            'class' => 'ModelAnalysisBiochemistry'
          },
          {
            'printOrder' => 0,
            'name' => 'modelAnalysisAnnotations',
            'type' => 'child',
            'class' => 'ModelAnalysisAnnotation'
          },
          {
            'printOrder' => 0,
            'name' => 'fbaFormulations',
            'type' => 'child',
            'class' => 'FBAFormulation'
          },
          {
            'printOrder' => 1,
            'name' => 'gapfillingFormulations',
            'type' => 'child',
            'class' => 'GapfillingFormulation'
          },
          {
            'printOrder' => 2,
            'name' => 'fbaProblems',
            'type' => 'child',
            'class' => 'FBAProblem'
          }
        ];

my $subobject_map = {modelAnalysisModels => 0, modelAnalysisMappings => 1, modelAnalysisBiochemistries => 2, modelAnalysisAnnotations => 3, fbaFormulations => 4, gapfillingFormulations => 5, fbaProblems => 6};
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
around 'modelAnalysisModels' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('modelAnalysisModels');
};
around 'modelAnalysisMappings' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('modelAnalysisMappings');
};
around 'modelAnalysisBiochemistries' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('modelAnalysisBiochemistries');
};
around 'modelAnalysisAnnotations' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('modelAnalysisAnnotations');
};
around 'fbaFormulations' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('fbaFormulations');
};
around 'gapfillingFormulations' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('gapfillingFormulations');
};
around 'fbaProblems' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('fbaProblems');
};


__PACKAGE__->meta->make_immutable;
1;
