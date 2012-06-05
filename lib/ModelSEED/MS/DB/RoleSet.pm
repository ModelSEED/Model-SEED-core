########################################################################
# ModelSEED::MS::DB::RoleSet - This is the moose object corresponding to the RoleSet object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::RoleSet;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::RoleSetRole;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::Mapping', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', lazy => 1, builder => '_builduuid', type => 'attribute', metaclass => 'Typed');
has modDate => (is => 'rw', isa => 'Str', printOrder => '-1', lazy => 1, builder => '_buildmodDate', type => 'attribute', metaclass => 'Typed');
has locked => (is => 'rw', isa => 'Int', printOrder => '-1', default => '0', type => 'attribute', metaclass => 'Typed');
has public => (is => 'rw', isa => 'Int', printOrder => '-1', default => '0', type => 'attribute', metaclass => 'Typed');
has name => (is => 'rw', isa => 'ModelSEED::varchar', printOrder => '3', default => '', type => 'attribute', metaclass => 'Typed');
has class => (is => 'rw', isa => 'ModelSEED::varchar', printOrder => '1', default => 'unclassified', type => 'attribute', metaclass => 'Typed');
has subclass => (is => 'rw', isa => 'ModelSEED::varchar', printOrder => '2', default => 'unclassified', type => 'attribute', metaclass => 'Typed');
has type => (is => 'rw', isa => 'Str', printOrder => '4', required => 1, type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has rolesetroles => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(RoleSetRole)', metaclass => 'Typed', reader => '_rolesetroles', printOrder => '-1');


# LINKS:
has id => (is => 'rw', lazy => 1, builder => '_buildid', isa => 'Str', type => 'id', metaclass => 'Typed');


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'RoleSet'; }

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
            'printOrder' => 3,
            'name' => 'name',
            'default' => '',
            'type' => 'ModelSEED::varchar',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 1,
            'name' => 'class',
            'default' => 'unclassified',
            'type' => 'ModelSEED::varchar',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 2,
            'name' => 'subclass',
            'default' => 'unclassified',
            'type' => 'ModelSEED::varchar',
            'perm' => 'rw'
          },
          {
            'len' => 32,
            'req' => 1,
            'printOrder' => 4,
            'name' => 'type',
            'type' => 'Str',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, modDate => 1, locked => 2, public => 3, name => 4, class => 5, subclass => 6, type => 7};
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
            'name' => 'rolesetroles',
            'type' => 'encompassed',
            'class' => 'RoleSetRole'
          }
        ];

my $subobject_map = {rolesetroles => 0};
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
sub _aliasowner { return 'Mapping'; }


# SUBOBJECT READERS:
around 'rolesetroles' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('rolesetroles');
};


__PACKAGE__->meta->make_immutable;
1;
