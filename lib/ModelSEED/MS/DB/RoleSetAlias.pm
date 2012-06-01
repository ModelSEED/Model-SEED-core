########################################################################
# ModelSEED::MS::DB::RoleSetAlias - This is the moose object corresponding to the RoleSetAlias object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::RoleSetAlias;
use ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::RoleSetAliasSet', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has roleset_uuid => (is => 'rw', isa => 'ModelSEED::uuid', required => 1, type => 'attribute', metaclass => 'Typed');
has alias => (is => 'rw', isa => 'Str', required => 1, type => 'attribute', metaclass => 'Typed');


# LINKS:
has roleset => (is => 'rw', isa => 'ModelSEED::MS::RoleSet', type => 'link(Mapping,rolesets,roleset_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildroleset', weak_ref => 1);


# BUILDERS:
sub _buildroleset {
    my ($self) = @_;
    return $self->getLinkedObject('Mapping','rolesets',$self->roleset_uuid());
}


# CONSTANTS:
sub _type { return 'RoleSetAlias'; }

my $attributes = [
          {
            'req' => 1,
            'name' => 'roleset_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'name' => 'alias',
            'type' => 'Str',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {roleset_uuid => 0, alias => 1};
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
