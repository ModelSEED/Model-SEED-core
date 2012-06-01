########################################################################
# ModelSEED::MS::DB::Annotation - This is the moose object corresponding to the Annotation object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Annotation;
use ModelSEED::MS::IndexedObject;
use ModelSEED::MS::Genome;
use ModelSEED::MS::Feature;
use ModelSEED::MS::SubsystemState;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::IndexedObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::Store', type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', lazy => 1, builder => '_builduuid', type => 'attribute', metaclass => 'Typed');
has modDate => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildmodDate', type => 'attribute', metaclass => 'Typed');
has locked => (is => 'rw', isa => 'Int', default => '0', type => 'attribute', metaclass => 'Typed');
has name => (is => 'rw', isa => 'ModelSEED::varchar', default => '', type => 'attribute', metaclass => 'Typed');
has mapping_uuid => (is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has genomes => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(Genome)', metaclass => 'Typed', reader => '_genomes');
has features => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(Feature)', metaclass => 'Typed', reader => '_features');
has subsystemStates => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(SubsystemState)', metaclass => 'Typed', reader => '_subsystemStates');


# LINKS:
has mapping => (is => 'rw', isa => 'ModelSEED::MS::Mapping', type => 'link(ModelSEED::Store,Mapping,mapping_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildmapping', weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }
sub _buildmapping {
    my ($self) = @_;
    return $self->getLinkedObject('ModelSEED::Store','Mapping',$self->mapping_uuid());
}


# CONSTANTS:
sub _type { return 'Annotation'; }

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
            'req' => 0,
            'name' => 'locked',
            'default' => '0',
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'name',
            'default' => '',
            'type' => 'ModelSEED::varchar',
            'perm' => 'rw'
          },
          {
            'name' => 'mapping_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, modDate => 1, locked => 2, name => 3, mapping_uuid => 4};
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
            'name' => 'genomes',
            'type' => 'child',
            'class' => 'Genome'
          },
          {
            'name' => 'features',
            'type' => 'child',
            'class' => 'Feature'
          },
          {
            'name' => 'subsystemStates',
            'type' => 'child',
            'class' => 'SubsystemState'
          }
        ];

my $subobject_map = {genomes => 0, features => 1, subsystemStates => 2};
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
around 'genomes' => sub {
    my ($orig, $self) = @_;
    return $self->_build_all_objects('genomes');
};
around 'features' => sub {
    my ($orig, $self) = @_;
    return $self->_build_all_objects('features');
};
around 'subsystemStates' => sub {
    my ($orig, $self) = @_;
    return $self->_build_all_objects('subsystemStates');
};


__PACKAGE__->meta->make_immutable;
1;
