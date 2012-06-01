########################################################################
# ModelSEED::MS::DB::Biomass - This is the moose object corresponding to the Biomass object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Biomass;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::BiomassCompound;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::Model', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', lazy => 1, builder => '_builduuid', type => 'attribute', metaclass => 'Typed');
has modDate => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildmodDate', type => 'attribute', metaclass => 'Typed');
has locked => (is => 'rw', isa => 'Int', default => '0', type => 'attribute', metaclass => 'Typed');
has name => (is => 'rw', isa => 'ModelSEED::varchar', default => '', type => 'attribute', metaclass => 'Typed');
has dna => (is => 'rw', isa => 'Num', default => '0.05', type => 'attribute', metaclass => 'Typed');
has rna => (is => 'rw', isa => 'Num', default => '0.1', type => 'attribute', metaclass => 'Typed');
has protein => (is => 'rw', isa => 'Num', default => '0.5', type => 'attribute', metaclass => 'Typed');
has cellwall => (is => 'rw', isa => 'Num', default => '0.15', type => 'attribute', metaclass => 'Typed');
has lipid => (is => 'rw', isa => 'Num', default => '0.05', type => 'attribute', metaclass => 'Typed');
has cofactor => (is => 'rw', isa => 'Num', default => '0.15', type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has biomasscompounds => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(BiomassCompound)', metaclass => 'Typed', reader => '_biomasscompounds');


# LINKS:
has id => (is => 'rw', lazy => 1, builder => '_buildid', isa => 'Str', type => 'id', metaclass => 'Typed');


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Biomass'; }

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
            'req' => 0,
            'name' => 'dna',
            'default' => '0.05',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'rna',
            'default' => '0.1',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'protein',
            'default' => '0.5',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'cellwall',
            'default' => '0.15',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'lipid',
            'default' => '0.05',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'cofactor',
            'default' => '0.15',
            'type' => 'Num',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, modDate => 1, locked => 2, name => 3, dna => 4, rna => 5, protein => 6, cellwall => 7, lipid => 8, cofactor => 9};
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
            'name' => 'biomasscompounds',
            'type' => 'encompassed',
            'class' => 'BiomassCompound'
          }
        ];

my $subobject_map = {biomasscompounds => 0};
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
sub _aliasowner { return 'Model'; }


# SUBOBJECT READERS:
around 'biomasscompounds' => sub {
    my ($orig, $self) = @_;
    return $self->_build_all_objects('biomasscompounds');
};


__PACKAGE__->meta->make_immutable;
1;
