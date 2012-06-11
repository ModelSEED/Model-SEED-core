########################################################################
# ModelSEED::MS::DB::ReactionInstance - This is the moose object corresponding to the ReactionInstance object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::ReactionInstance;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::InstanceTransport;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::Biochemistry', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', lazy => 1, builder => '_build_uuid', type => 'attribute', metaclass => 'Typed');
has modDate => (is => 'rw', isa => 'Str', printOrder => '-1', lazy => 1, builder => '_build_modDate', type => 'attribute', metaclass => 'Typed');
has locked => (is => 'rw', isa => 'Int', printOrder => '-1', default => '0', type => 'attribute', metaclass => 'Typed');
has reaction_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '7', required => 1, type => 'attribute', metaclass => 'Typed');
has direction => (is => 'rw', isa => 'Str', printOrder => '4', default => '=', type => 'attribute', metaclass => 'Typed');
has compartment_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '8', required => 1, type => 'attribute', metaclass => 'Typed');
has sourceEquation => (is => 'rw', isa => 'Str', printOrder => '3', required => 1, type => 'attribute', metaclass => 'Typed');
has transprotonNature => (is => 'rw', isa => 'ModelSEED::varchar', printOrder => '6', default => '', type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has transports => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(InstanceTransport)', metaclass => 'Typed', reader => '_transports', printOrder => '-1');


# LINKS:
has compartment => (is => 'rw', isa => 'ModelSEED::MS::Compartment', type => 'link(Biochemistry,compartments,compartment_uuid)', metaclass => 'Typed', lazy => 1, builder => '_build_compartment', weak_ref => 1);
has reaction => (is => 'rw', isa => 'ModelSEED::MS::Reaction', type => 'link(Biochemistry,reactions,reaction_uuid)', metaclass => 'Typed', lazy => 1, builder => '_build_reaction', weak_ref => 1);
has id => (is => 'rw', lazy => 1, builder => '_build_id', isa => 'Str', type => 'id', metaclass => 'Typed');


# BUILDERS:
sub _build_uuid { return Data::UUID->new()->create_str(); }
sub _build_modDate { return DateTime->now()->datetime(); }
sub _build_compartment {
  my ($self) = @_;
  return $self->getLinkedObject('Biochemistry','compartments',$self->compartment_uuid());
}
sub _build_reaction {
  my ($self) = @_;
  return $self->getLinkedObject('Biochemistry','reactions',$self->reaction_uuid());
}


# CONSTANTS:
sub _type { return 'ReactionInstance'; }

my $attributes = [
          {
            'len' => 36,
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
            'req' => 1,
            'printOrder' => 7,
            'name' => 'reaction_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'len' => 1,
            'req' => 0,
            'printOrder' => 4,
            'name' => 'direction',
            'default' => '=',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'len' => 36,
            'req' => 1,
            'printOrder' => 8,
            'name' => 'compartment_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'len' => 36,
            'req' => 1,
            'printOrder' => 3,
            'name' => 'sourceEquation',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 6,
            'name' => 'transprotonNature',
            'default' => '',
            'type' => 'ModelSEED::varchar',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, modDate => 1, locked => 2, reaction_uuid => 3, direction => 4, compartment_uuid => 5, sourceEquation => 6, transprotonNature => 7};
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
            'name' => 'transports',
            'type' => 'encompassed',
            'class' => 'InstanceTransport'
          }
        ];

my $subobject_map = {transports => 0};
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
sub _aliasowner { return 'Biochemistry'; }


# SUBOBJECT READERS:
around 'transports' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('transports');
};


__PACKAGE__->meta->make_immutable;
1;
