########################################################################
# ModelSEED::MS::DB::Model - This is the moose object corresponding to the Model object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Model;
use ModelSEED::MS::IndexedObject;
use ModelSEED::MS::Biomass;
use ModelSEED::MS::ModelCompartment;
use ModelSEED::MS::ModelCompound;
use ModelSEED::MS::ModelReaction;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::IndexedObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::Store', type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', lazy => 1, builder => '_builduuid', type => 'attribute', metaclass => 'Typed');
has modDate => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildmodDate', type => 'attribute', metaclass => 'Typed');
has locked => (is => 'rw', isa => 'Int', default => '0', type => 'attribute', metaclass => 'Typed');
has public => (is => 'rw', isa => 'Int', default => '0', type => 'attribute', metaclass => 'Typed');
has id => (is => 'rw', isa => 'ModelSEED::varchar', required => 1, type => 'attribute', metaclass => 'Typed');
has name => (is => 'rw', isa => 'Str', default => '', type => 'attribute', metaclass => 'Typed');
has version => (is => 'rw', isa => 'Int', default => '0', type => 'attribute', metaclass => 'Typed');
has type => (is => 'rw', isa => 'Str', default => 'Singlegenome', type => 'attribute', metaclass => 'Typed');
has status => (is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed');
has growth => (is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed');
has current => (is => 'rw', isa => 'Int', default => '1', type => 'attribute', metaclass => 'Typed');
has mapping_uuid => (is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed');
has biochemistry_uuid => (is => 'rw', isa => 'ModelSEED::uuid', required => 1, type => 'attribute', metaclass => 'Typed');
has annotation_uuid => (is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has biomasses => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(Biomass)', metaclass => 'Typed', reader => '_biomasses');
has modelcompartments => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(ModelCompartment)', metaclass => 'Typed', reader => '_modelcompartments');
has modelcompounds => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(ModelCompound)', metaclass => 'Typed', reader => '_modelcompounds');
has modelreactions => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(ModelReaction)', metaclass => 'Typed', reader => '_modelreactions');


# LINKS:
has biochemistry => (is => 'rw', isa => 'ModelSEED::MS::Biochemistry', type => 'link(ModelSEED::Store,Biochemistry,biochemistry_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildbiochemistry', weak_ref => 1);
has mapping => (is => 'rw', isa => 'ModelSEED::MS::Mapping', type => 'link(ModelSEED::Store,Mapping,mapping_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildmapping', weak_ref => 1);
has annotation => (is => 'rw', isa => 'ModelSEED::MS::Annotation', type => 'link(ModelSEED::Store,Annotation,annotation_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildannotation', weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }
sub _buildbiochemistry {
    my ($self) = @_;
    return $self->getLinkedObject('ModelSEED::Store','Biochemistry',$self->biochemistry_uuid());
}
sub _buildmapping {
    my ($self) = @_;
    return $self->getLinkedObject('ModelSEED::Store','Mapping',$self->mapping_uuid());
}
sub _buildannotation {
    my ($self) = @_;
    return $self->getLinkedObject('ModelSEED::Store','Annotation',$self->annotation_uuid());
}


# CONSTANTS:
sub _type { return 'Model'; }

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
            'name' => 'public',
            'default' => '0',
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'name' => 'id',
            'type' => 'ModelSEED::varchar',
            'perm' => 'rw'
          },
          {
            'len' => 32,
            'req' => 0,
            'name' => 'name',
            'default' => '',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'version',
            'default' => '0',
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'len' => 32,
            'req' => 0,
            'name' => 'type',
            'default' => 'Singlegenome',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'len' => 32,
            'req' => 0,
            'name' => 'status',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'growth',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'current',
            'default' => '1',
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'mapping_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'name' => 'biochemistry_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'annotation_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, modDate => 1, locked => 2, public => 3, id => 4, name => 5, version => 6, type => 7, status => 8, growth => 9, current => 10, mapping_uuid => 11, biochemistry_uuid => 12, annotation_uuid => 13};
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
            'name' => 'biomasses',
            'type' => 'child',
            'class' => 'Biomass'
          },
          {
            'name' => 'modelcompartments',
            'type' => 'child',
            'class' => 'ModelCompartment'
          },
          {
            'name' => 'modelcompounds',
            'type' => 'child',
            'class' => 'ModelCompound'
          },
          {
            'name' => 'modelreactions',
            'type' => 'child',
            'class' => 'ModelReaction'
          }
        ];

my $subobject_map = {biomasses => 0, modelcompartments => 1, modelcompounds => 2, modelreactions => 3};
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
around 'biomasses' => sub {
    my ($orig, $self) = @_;
    return $self->_build_all_objects('biomasses');
};
around 'modelcompartments' => sub {
    my ($orig, $self) = @_;
    return $self->_build_all_objects('modelcompartments');
};
around 'modelcompounds' => sub {
    my ($orig, $self) = @_;
    return $self->_build_all_objects('modelcompounds');
};
around 'modelreactions' => sub {
    my ($orig, $self) = @_;
    return $self->_build_all_objects('modelreactions');
};


__PACKAGE__->meta->make_immutable;
1;
