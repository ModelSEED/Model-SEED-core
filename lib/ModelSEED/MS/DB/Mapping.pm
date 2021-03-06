########################################################################
# ModelSEED::MS::DB::Mapping - This is the moose object corresponding to the Mapping object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Mapping;
our $VERSION = 1;
use ModelSEED::MS::IndexedObject;
use ModelSEED::MS::UniversalReaction;
use ModelSEED::MS::BiomassTemplate;
use ModelSEED::MS::Role;
use ModelSEED::MS::RoleSet;
use ModelSEED::MS::Complex;
use ModelSEED::MS::AliasSet;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::IndexedObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::Store', type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', lazy => 1, builder => '_build_uuid', type => 'attribute', metaclass => 'Typed');
has modDate => (is => 'rw', isa => 'Str', printOrder => '-1', lazy => 1, builder => '_build_modDate', type => 'attribute', metaclass => 'Typed');
has locked => (is => 'rw', isa => 'Int', printOrder => '-1', default => '0', type => 'attribute', metaclass => 'Typed');
has public => (is => 'rw', isa => 'Int', printOrder => '-1', default => '0', type => 'attribute', metaclass => 'Typed');
has name => (is => 'rw', isa => 'ModelSEED::varchar', printOrder => '1', default => '', type => 'attribute', metaclass => 'Typed');
has defaultNameSpace => (is => 'rw', isa => 'Str', printOrder => '2', default => 'SEED', type => 'attribute', metaclass => 'Typed');
has biochemistry_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '3', type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has universalReactions => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(UniversalReaction)', metaclass => 'Typed', reader => '_universalReactions', printOrder => '0');
has biomassTemplates => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(BiomassTemplate)', metaclass => 'Typed', reader => '_biomassTemplates', printOrder => '1');
has roles => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(Role)', metaclass => 'Typed', reader => '_roles', printOrder => '2');
has rolesets => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(RoleSet)', metaclass => 'Typed', reader => '_rolesets', printOrder => '3');
has complexes => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(Complex)', metaclass => 'Typed', reader => '_complexes', printOrder => '4');
has aliasSets => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(AliasSet)', metaclass => 'Typed', reader => '_aliasSets', printOrder => '-1');


# LINKS:
has biochemistry => (is => 'rw', isa => 'ModelSEED::MS::Biochemistry', type => 'link(ModelSEED::Store,Biochemistry,biochemistry_uuid)', metaclass => 'Typed', lazy => 1, builder => '_build_biochemistry');


# BUILDERS:
sub _build_uuid { return Data::UUID->new()->create_str(); }
sub _build_modDate { return DateTime->now()->datetime(); }
sub _build_biochemistry {
  my ($self) = @_;
  return $self->getLinkedObject('ModelSEED::Store','Biochemistry',$self->biochemistry_uuid());
}


# CONSTANTS:
sub __version__ { return $VERSION; }
sub _type { return 'Mapping'; }

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
            'req' => 0,
            'printOrder' => 1,
            'name' => 'name',
            'default' => '',
            'type' => 'ModelSEED::varchar',
            'perm' => 'rw'
          },
          {
            'len' => 32,
            'req' => 0,
            'printOrder' => 2,
            'name' => 'defaultNameSpace',
            'default' => 'SEED',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 3,
            'name' => 'biochemistry_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, modDate => 1, locked => 2, public => 3, name => 4, defaultNameSpace => 5, biochemistry_uuid => 6};
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
            'name' => 'universalReactions',
            'type' => 'child',
            'class' => 'UniversalReaction'
          },
          {
            'printOrder' => 1,
            'name' => 'biomassTemplates',
            'type' => 'child',
            'class' => 'BiomassTemplate'
          },
          {
            'printOrder' => 2,
            'name' => 'roles',
            'type' => 'child',
            'class' => 'Role'
          },
          {
            'printOrder' => 3,
            'name' => 'rolesets',
            'type' => 'child',
            'class' => 'RoleSet'
          },
          {
            'printOrder' => 4,
            'name' => 'complexes',
            'type' => 'child',
            'class' => 'Complex'
          },
          {
            'printOrder' => -1,
            'name' => 'aliasSets',
            'type' => 'child',
            'class' => 'AliasSet'
          }
        ];

my $subobject_map = {universalReactions => 0, biomassTemplates => 1, roles => 2, rolesets => 3, complexes => 4, aliasSets => 5};
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
around 'universalReactions' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('universalReactions');
};
around 'biomassTemplates' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('biomassTemplates');
};
around 'roles' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('roles');
};
around 'rolesets' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('rolesets');
};
around 'complexes' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('complexes');
};
around 'aliasSets' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('aliasSets');
};


__PACKAGE__->meta->make_immutable;
1;
