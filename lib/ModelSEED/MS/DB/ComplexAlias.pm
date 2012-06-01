########################################################################
# ModelSEED::MS::DB::ComplexAlias - This is the moose object corresponding to the ComplexAlias object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::ComplexAlias;
use ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::ComplexAliasSet', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has complex_uuid => (is => 'rw', isa => 'ModelSEED::uuid', required => 1, type => 'attribute', metaclass => 'Typed');
has alias => (is => 'rw', isa => 'Str', required => 1, type => 'attribute', metaclass => 'Typed');


# LINKS:
has complex => (is => 'rw', isa => 'ModelSEED::MS::Complex', type => 'link(Mapping,complexes,complex_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildcomplex', weak_ref => 1);


# BUILDERS:
sub _buildcomplex {
    my ($self) = @_;
    return $self->getLinkedObject('Mapping','complexes',$self->complex_uuid());
}


# CONSTANTS:
sub _type { return 'ComplexAlias'; }

my $attributes = [
          {
            'req' => 1,
            'name' => 'complex_uuid',
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

my $attribute_map = {complex_uuid => 0, alias => 1};
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
