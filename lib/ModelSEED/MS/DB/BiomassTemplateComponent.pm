########################################################################
# ModelSEED::MS::DB::BiomassTemplateComponent - This is the moose object corresponding to the BiomassTemplateComponent object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::BiomassTemplateComponent;
use ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::BiomassTemplate', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', required => 1, lazy => 1, builder => '_builduuid', type => 'attribute', metaclass => 'Typed');
has modDate => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildmodDate', type => 'attribute', metaclass => 'Typed');
has class => (is => 'rw', isa => 'Str', default => '0', type => 'attribute', metaclass => 'Typed');
has compound_uuid => (is => 'rw', isa => 'Str', default => '0', type => 'attribute', metaclass => 'Typed');
has coefficientType => (is => 'rw', isa => 'Str', default => '0', type => 'attribute', metaclass => 'Typed');
has coefficient => (is => 'rw', isa => 'Num', default => '0', type => 'attribute', metaclass => 'Typed');
has condition => (is => 'rw', isa => 'Str', default => '0', type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# LINKS:
has compound => (is => 'rw', isa => 'ModelSEED::MS::Compound', type => 'link(Biochemistry,compounds,compound_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildcompound', weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }
sub _buildcompound {
    my ($self) = @_;
    return $self->getLinkedObject('Biochemistry','compounds',$self->compound_uuid());
}


# CONSTANTS:
sub _type { return 'BiomassTemplateComponent'; }

my $attributes = [
          {
            'req' => 1,
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
            'name' => 'class',
            'default' => '0',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'compound_uuid',
            'default' => '0',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'coefficientType',
            'default' => '0',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'coefficient',
            'default' => '0',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'condition',
            'default' => '0',
            'type' => 'Str',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, modDate => 1, class => 2, compound_uuid => 3, coefficientType => 4, coefficient => 5, condition => 6};
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
