########################################################################
# ModelSEED::MS::DB::ModelReaction - This is the moose object corresponding to the ModelReaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::ModelReaction;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::ModelReactionRawGPR;
use ModelSEED::MS::ModelReactionReagent;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::Model', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', lazy => 1, builder => '_builduuid', type => 'attribute', metaclass => 'Typed');
has modDate => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildmodDate', type => 'attribute', metaclass => 'Typed');
has reaction_uuid => (is => 'rw', isa => 'ModelSEED::uuid', required => 1, type => 'attribute', metaclass => 'Typed');
has direction => (is => 'rw', isa => 'Str', default => '=', type => 'attribute', metaclass => 'Typed');
has protons => (is => 'rw', isa => 'Num', default => '0', type => 'attribute', metaclass => 'Typed');
has modelcompartment_uuid => (is => 'rw', isa => 'ModelSEED::uuid', required => 1, type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has gpr => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(ModelReactionRawGPR)', metaclass => 'Typed', reader => '_gpr');
has modelReactionReagents => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(ModelReactionReagent)', metaclass => 'Typed', reader => '_modelReactionReagents');


# LINKS:
has reaction => (is => 'rw', isa => 'ModelSEED::MS::Reaction', type => 'link(Biochemistry,reactions,reaction_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildreaction', weak_ref => 1);
has modelcompartment => (is => 'rw', isa => 'ModelSEED::MS::ModelCompartment', type => 'link(Model,modelcompartments,modelcompartment_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildmodelcompartment', weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }
sub _buildreaction {
    my ($self) = @_;
    return $self->getLinkedObject('Biochemistry','reactions',$self->reaction_uuid());
}
sub _buildmodelcompartment {
    my ($self) = @_;
    return $self->getLinkedObject('Model','modelcompartments',$self->modelcompartment_uuid());
}


# CONSTANTS:
sub _type { return 'ModelReaction'; }

my $attributes = [
          {
            'req' => 0,
            'name' => 'uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'modDate',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'name' => 'reaction_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'len' => 1,
            'req' => 0,
            'name' => 'direction',
            'default' => '=',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'protons',
            'default' => 0,
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'name' => 'modelcompartment_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, modDate => 1, reaction_uuid => 2, direction => 3, protons => 4, modelcompartment_uuid => 5};
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
            'name' => 'gpr',
            'type' => 'encompassed',
            'class' => 'ModelReactionRawGPR'
          },
          {
            'name' => 'modelReactionReagents',
            'type' => 'encompassed',
            'class' => 'ModelReactionReagent'
          }
        ];

my $subobject_map = {gpr => 0, modelReactionReagents => 1};
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
around 'gpr' => sub {
    my ($orig, $self) = @_;
    return $self->_build_all_objects('gpr');
};
around 'modelReactionReagents' => sub {
    my ($orig, $self) = @_;
    return $self->_build_all_objects('modelReactionReagents');
};


__PACKAGE__->meta->make_immutable;
1;
