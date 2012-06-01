########################################################################
# ModelSEED::MS::DB::FBACompoundVariable - This is the moose object corresponding to the FBACompoundVariable object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::FBACompoundVariable;
use ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::FBAResults', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has modelcompound_uuid => (is => 'rw', isa => 'ModelSEED::uuid', required => 1, type => 'attribute', metaclass => 'Typed');
has variableType => (is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed');
has lowerBound => (is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed');
has upperBound => (is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed');
has min => (is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed');
has max => (is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed');
has value => (is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed');


# LINKS:
has modelcompound => (is => 'rw', isa => 'ModelSEED::MS::ModelCompound', type => 'link(Model,modelcompounds,modelcompound_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildmodelcompound', weak_ref => 1);


# BUILDERS:
sub _buildmodelcompound {
    my ($self) = @_;
    return $self->getLinkedObject('Model','modelcompounds',$self->modelcompound_uuid());
}


# CONSTANTS:
sub _type { return 'FBACompoundVariable'; }

my $attributes = [
          {
            'req' => 1,
            'name' => 'modelcompound_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'len' => 1,
            'req' => 0,
            'name' => 'variableType',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'len' => 1,
            'req' => 0,
            'name' => 'lowerBound',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'len' => 1,
            'req' => 0,
            'name' => 'upperBound',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'len' => 1,
            'req' => 0,
            'name' => 'min',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'len' => 1,
            'req' => 0,
            'name' => 'max',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'len' => 1,
            'req' => 0,
            'name' => 'value',
            'type' => 'Str',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {modelcompound_uuid => 0, variableType => 1, lowerBound => 2, upperBound => 3, min => 4, max => 5, value => 6};
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
