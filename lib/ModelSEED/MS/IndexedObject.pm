########################################################################
# ModelSEED::MS::IndexedObject - This is the moose object corresponding to the IndexedObject object
# Author: Christopher Henry, Scott Devoid, and Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 3/11/2012
########################################################################
package ModelSEED::MS::IndexedObject;

use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject;

use Data::Dumper;

extends 'ModelSEED::MS::BaseObject';

has indices => ( is => 'rw', isa => 'HashRef', default => sub { return {} } );

sub BUILD {
    my ($self) = @_;

    # index on uuid for subobjects
    my $indices = $self->indices;
    foreach my $subobj (@{$self->_subobjects}) {
        my $name = $subobj->{name};
        my $method = "_$name";
        my $subobjs = $self->$method();
        foreach my $so_info (@$subobjs) {
            my $uuid = $so_info->{data}->{uuid};
            if (defined($uuid)) {
                $indices->{$name}->{uuid}->{$uuid} = $so_info;
            }
        }
    }
}

sub getObject {
    my ($self, $attribute, $uuid) = @_;

    my $objs = $self->getObjects($attribute, [$uuid]);

    if (scalar @$objs == 1) {
        return $objs->[0];
    } else {
        return undef;
    }
}

sub getObjects {
    my ($self, $attribute, $uuids) = @_;

    my $results = [];
    my $indices = $self->indices;
    foreach my $obj_uuid (@$uuids) {
        my $obj_info = $indices->{$attribute}->{uuid}->{$obj_uuid};
        if (defined($obj_info)) {
            push(@$results, $self->_build_object($attribute, $obj_info));
        } else {
            push(@$results, undef);
        }
    }

    return $results;
}

1;
