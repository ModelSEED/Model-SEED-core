########################################################################
# ModelSEED::MS::DB::Mapping - This is the moose object corresponding to the Mapping object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Mapping;
use ModelSEED::MS::IndexedObject;
use ModelSEED::MS::UniversalReaction;
use ModelSEED::MS::BiomassTemplate;
use ModelSEED::MS::Role;
use ModelSEED::MS::RoleSet;
use ModelSEED::MS::Complex;
use ModelSEED::MS::RoleSetAliasSet;
use ModelSEED::MS::RoleAliasSet;
use ModelSEED::MS::ComplexAliasSet;
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
has name => (is => 'rw', isa => 'ModelSEED::varchar', default => '', type => 'attribute', metaclass => 'Typed');
has biochemistry_uuid => (is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has universalReactions => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(UniversalReaction)', metaclass => 'Typed', reader => '_universalReactions');
has biomassTemplates => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(BiomassTemplate)', metaclass => 'Typed', reader => '_biomassTemplates');
has roles => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(Role)', metaclass => 'Typed', reader => '_roles');
has rolesets => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(RoleSet)', metaclass => 'Typed', reader => '_rolesets');
has complexes => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(Complex)', metaclass => 'Typed', reader => '_complexes');
has roleSetAliasSets => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(RoleSetAliasSet)', metaclass => 'Typed', reader => '_roleSetAliasSets');
has roleAliasSets => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(RoleAliasSet)', metaclass => 'Typed', reader => '_roleAliasSets');
has complexAliasSets => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(ComplexAliasSet)', metaclass => 'Typed', reader => '_complexAliasSets');


# LINKS:
has biochemistry => (is => 'rw', isa => 'ModelSEED::MS::Biochemistry', type => 'link(ModelSEED::Store,Biochemistry,biochemistry_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildbiochemistry', weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }
sub _buildbiochemistry {
    my ($self) = @_;
    return $self->getLinkedObject('ModelSEED::Store','Biochemistry',$self->biochemistry_uuid());
}


# CONSTANTS:
sub _type { return 'Mapping'; }

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
            'req' => 0,
            'name' => 'name',
            'default' => '',
            'type' => 'ModelSEED::varchar',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'biochemistry_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, modDate => 1, locked => 2, public => 3, name => 4, biochemistry_uuid => 5};
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
            'name' => 'universalReactions',
            'type' => 'child',
            'class' => 'UniversalReaction'
          },
          {
            'name' => 'biomassTemplates',
            'type' => 'child',
            'class' => 'BiomassTemplate'
          },
          {
            'name' => 'roles',
            'type' => 'child',
            'class' => 'Role'
          },
          {
            'name' => 'rolesets',
            'type' => 'child',
            'class' => 'RoleSet'
          },
          {
            'name' => 'complexes',
            'type' => 'child',
            'class' => 'Complex'
          },
          {
            'name' => 'roleSetAliasSets',
            'type' => 'child',
            'class' => 'RoleSetAliasSet'
          },
          {
            'name' => 'roleAliasSets',
            'type' => 'child',
            'class' => 'RoleAliasSet'
          },
          {
            'name' => 'complexAliasSets',
            'type' => 'child',
            'class' => 'ComplexAliasSet'
          }
        ];

my $subobject_map = {universalReactions => 0, biomassTemplates => 1, roles => 2, rolesets => 3, complexes => 4, roleSetAliasSets => 5, roleAliasSets => 6, complexAliasSets => 7};
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
around 'universalReactions' => sub {
    my ($orig, $self) = @_;
    return $self->_build_all_objects('universalReactions');
};
around 'biomassTemplates' => sub {
    my ($orig, $self) = @_;
    return $self->_build_all_objects('biomassTemplates');
};
around 'roles' => sub {
    my ($orig, $self) = @_;
    return $self->_build_all_objects('roles');
};
around 'rolesets' => sub {
    my ($orig, $self) = @_;
    return $self->_build_all_objects('rolesets');
};
around 'complexes' => sub {
    my ($orig, $self) = @_;
    return $self->_build_all_objects('complexes');
};
around 'roleSetAliasSets' => sub {
    my ($orig, $self) = @_;
    return $self->_build_all_objects('roleSetAliasSets');
};
around 'roleAliasSets' => sub {
    my ($orig, $self) = @_;
    return $self->_build_all_objects('roleAliasSets');
};
around 'complexAliasSets' => sub {
    my ($orig, $self) = @_;
    return $self->_build_all_objects('complexAliasSets');
};


__PACKAGE__->meta->make_immutable;
1;
