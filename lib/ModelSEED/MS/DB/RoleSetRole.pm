########################################################################
# ModelSEED::MS::DB::RoleSetRole - This is the moose object corresponding to the RoleSetRole object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::RoleSetRole;
use ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::RoleSet', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has role_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');


# LINKS:
has role => (is => 'rw', isa => 'ModelSEED::MS::Role', type => 'link(Mapping,roles,role_uuid)', metaclass => 'Typed', lazy => 1, builder => '_build_role', weak_ref => 1);


# BUILDERS:
sub _build_role {
  my ($self) = @_;
  return $self->getLinkedObject('Mapping','roles',$self->role_uuid());
}


# CONSTANTS:
sub _type { return 'RoleSetRole'; }

my $attributes = [
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'role_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {role_uuid => 0};
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

my $subobjects = [];

my $subobject_map = {};
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


__PACKAGE__->meta->make_immutable;
1;
