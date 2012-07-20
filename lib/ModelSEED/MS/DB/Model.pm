########################################################################
# ModelSEED::MS::DB::Model - This is the moose object corresponding to the Model object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Model;
our $VERSION = 1;
use ModelSEED::MS::IndexedObject;
use ModelSEED::MS::Biomass;
use ModelSEED::MS::ModelCompartment;
use ModelSEED::MS::ModelCompound;
use ModelSEED::MS::ModelReaction;
use ModelSEED::MS::FBAFormulation;
use ModelSEED::MS::GapfillingFormulation;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::IndexedObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::Store', type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', lazy => 1, builder => '_build_uuid', type => 'attribute', metaclass => 'Typed');
has defaultNameSpace => (is => 'rw', isa => 'Str', printOrder => '3', default => 'ModelSEED', type => 'attribute', metaclass => 'Typed');
has modDate => (is => 'rw', isa => 'Str', printOrder => '-1', lazy => 1, builder => '_build_modDate', type => 'attribute', metaclass => 'Typed');
has locked => (is => 'rw', isa => 'Int', printOrder => '-1', default => '0', type => 'attribute', metaclass => 'Typed');
has public => (is => 'rw', isa => 'Int', printOrder => '-1', default => '0', type => 'attribute', metaclass => 'Typed');
has id => (is => 'rw', isa => 'ModelSEED::varchar', printOrder => '1', required => 1, type => 'attribute', metaclass => 'Typed');
has name => (is => 'rw', isa => 'Str', printOrder => '2', default => '', type => 'attribute', metaclass => 'Typed');
has version => (is => 'rw', isa => 'Int', printOrder => '3', default => '0', type => 'attribute', metaclass => 'Typed');
has type => (is => 'rw', isa => 'Str', printOrder => '5', default => 'Singlegenome', type => 'attribute', metaclass => 'Typed');
has status => (is => 'rw', isa => 'Str', printOrder => '7', type => 'attribute', metaclass => 'Typed');
has growth => (is => 'rw', isa => 'Num', printOrder => '6', type => 'attribute', metaclass => 'Typed');
has current => (is => 'rw', isa => 'Int', printOrder => '4', default => '1', type => 'attribute', metaclass => 'Typed');
has mapping_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '8', type => 'attribute', metaclass => 'Typed');
has biochemistry_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '9', required => 1, type => 'attribute', metaclass => 'Typed');
has annotation_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '10', type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has biomasses => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(Biomass)', metaclass => 'Typed', reader => '_biomasses', printOrder => '0');
has modelcompartments => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(ModelCompartment)', metaclass => 'Typed', reader => '_modelcompartments', printOrder => '1');
has modelcompounds => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(ModelCompound)', metaclass => 'Typed', reader => '_modelcompounds', printOrder => '2');
has modelreactions => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(ModelReaction)', metaclass => 'Typed', reader => '_modelreactions', printOrder => '3');
has fbaFormulations => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(FBAFormulation)', metaclass => 'Typed', reader => '_fbaFormulations', printOrder => '-1');
has Gapfillingformulations => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(GapfillingFormulation)', metaclass => 'Typed', reader => '_Gapfillingformulations', printOrder => '-1');


# LINKS:
has biochemistry => (is => 'rw', isa => 'ModelSEED::MS::Biochemistry', type => 'link(ModelSEED::Store,Biochemistry,biochemistry_uuid)', metaclass => 'Typed', lazy => 1, builder => '_build_biochemistry');
has mapping => (is => 'rw', isa => 'ModelSEED::MS::Mapping', type => 'link(ModelSEED::Store,Mapping,mapping_uuid)', metaclass => 'Typed', lazy => 1, builder => '_build_mapping');
has annotation => (is => 'rw', isa => 'ModelSEED::MS::Annotation', type => 'link(ModelSEED::Store,Annotation,annotation_uuid)', metaclass => 'Typed', lazy => 1, builder => '_build_annotation');
has modelanalysis => (is => 'rw', isa => 'ModelSEED::MS::ModelAnalysis', type => 'link(ModelSEED::Store,ModelAnalysis,modelanalysis_uuid)', metaclass => 'Typed', lazy => 1, builder => '_build_modelanalysis');


# BUILDERS:
sub _build_uuid { return Data::UUID->new()->create_str(); }
sub _build_modDate { return DateTime->now()->datetime(); }
sub _build_biochemistry {
  my ($self) = @_;
  return $self->getLinkedObject('ModelSEED::Store','Biochemistry',$self->biochemistry_uuid());
}
sub _build_mapping {
  my ($self) = @_;
  return $self->getLinkedObject('ModelSEED::Store','Mapping',$self->mapping_uuid());
}
sub _build_annotation {
  my ($self) = @_;
  return $self->getLinkedObject('ModelSEED::Store','Annotation',$self->annotation_uuid());
}
sub _build_modelanalysis {
  my ($self) = @_;
  return $self->getLinkedObject('ModelSEED::Store','ModelAnalysis',$self->modelanalysis_uuid());
}


# CONSTANTS:
sub __version__ { return $VERSION; }
sub _type { return 'Model'; }

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
          },
          {
            'req' => 1,
            'printOrder' => 1,
            'name' => 'id',
            'type' => 'ModelSEED::varchar',
            'perm' => 'rw'
          },
          {
            'len' => 32,
            'req' => 0,
            'printOrder' => 2,
            'name' => 'name',
            'default' => '',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 3,
            'name' => 'version',
            'default' => '0',
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'len' => 32,
            'req' => 0,
            'printOrder' => 5,
            'name' => 'type',
            'default' => 'Singlegenome',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'len' => 32,
            'req' => 0,
            'printOrder' => 7,
            'name' => 'status',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 6,
            'name' => 'growth',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 4,
            'name' => 'current',
            'default' => '1',
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 8,
            'name' => 'mapping_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 9,
            'name' => 'biochemistry_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 10,
            'name' => 'annotation_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, defaultNameSpace => 1, modDate => 2, locked => 3, public => 4, id => 5, name => 6, version => 7, type => 8, status => 9, growth => 10, current => 11, mapping_uuid => 12, biochemistry_uuid => 13, annotation_uuid => 14};
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
            'name' => 'biomasses',
            'type' => 'child',
            'class' => 'Biomass'
          },
          {
            'printOrder' => 1,
            'name' => 'modelcompartments',
            'type' => 'child',
            'class' => 'ModelCompartment'
          },
          {
            'printOrder' => 2,
            'name' => 'modelcompounds',
            'type' => 'child',
            'class' => 'ModelCompound'
          },
          {
            'printOrder' => 3,
            'name' => 'modelreactions',
            'type' => 'child',
            'class' => 'ModelReaction'
          },
          {
            'printOrder' => -1,
            'name' => 'fbaFormulations',
            'type' => 'child',
            'class' => 'FBAFormulation'
          },
          {
            'printOrder' => -1,
            'name' => 'Gapfillingformulations',
            'type' => 'child',
            'class' => 'GapfillingFormulation'
          }
        ];

my $subobject_map = {biomasses => 0, modelcompartments => 1, modelcompounds => 2, modelreactions => 3, fbaFormulations => 4, Gapfillingformulations => 5};
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
around 'biomasses' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('biomasses');
};
around 'modelcompartments' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('modelcompartments');
};
around 'modelcompounds' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('modelcompounds');
};
around 'modelreactions' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('modelreactions');
};
around 'fbaFormulations' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('fbaFormulations');
};
around 'Gapfillingformulations' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('Gapfillingformulations');
};


__PACKAGE__->meta->make_immutable;
1;
