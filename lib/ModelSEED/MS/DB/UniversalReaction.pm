########################################################################
# ModelSEED::MS::DB::UniversalReaction - This is the moose object corresponding to the UniversalReaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::UniversalReaction;
use ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::Mapping', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has type => (is => 'rw', isa => 'Str', required => 1, type => 'attribute', metaclass => 'Typed');
has reactioninstance_uuid => (is => 'rw', isa => 'ModelSEED::uuid', required => 1, type => 'attribute', metaclass => 'Typed');


# LINKS:
has reactioninstance => (is => 'rw', isa => 'ModelSEED::MS::ReactionInstance', type => 'link(Biochemistry,reactioninstances,reactioninstance_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildreactioninstance', weak_ref => 1);


# BUILDERS:
sub _buildreactioninstance {
    my ($self) = @_;
    return $self->getLinkedObject('Biochemistry','reactioninstances',$self->reactioninstance_uuid());
}


# CONSTANTS:
sub _type { return 'UniversalReaction'; }

my $attributes = [
          {
            'req' => 1,
            'name' => 'type',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'name' => 'reactioninstance_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {type => 0, reactioninstance_uuid => 1};
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
