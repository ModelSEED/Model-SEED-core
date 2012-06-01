########################################################################
# ModelSEED::MS::DB::UptakeMeasurement - This is the moose object corresponding to the UptakeMeasurement object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::UptakeMeasurement;
use ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::ExperimentDataPoint', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has value => (is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed');
has compound_uuid => (is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed');
has type => (is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed');


# LINKS:
has compound => (is => 'rw', isa => 'ModelSEED::MS::Compound', type => 'link(Biochemistry,compounds,compound_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildcompound', weak_ref => 1);


# BUILDERS:
sub _buildcompound {
    my ($self) = @_;
    return $self->getLinkedObject('Biochemistry','compounds',$self->compound_uuid());
}


# CONSTANTS:
sub _type { return 'UptakeMeasurement'; }

my $attributes = [
          {
            'req' => 0,
            'name' => 'value',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'compound_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'type',
            'type' => 'Str',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {value => 0, compound_uuid => 1, type => 2};
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
