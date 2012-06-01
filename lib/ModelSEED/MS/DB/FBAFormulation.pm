########################################################################
# ModelSEED::MS::DB::FBAFormulation - This is the moose object corresponding to the FBAFormulation object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::FBAFormulation;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::FBAObjectiveTerm;
use ModelSEED::MS::FBACompoundConstraint;
use ModelSEED::MS::FBAReactionConstraint;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::model_uuid', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', lazy => 1, builder => '_builduuid', type => 'attribute', metaclass => 'Typed');
has modDate => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildmodDate', type => 'attribute', metaclass => 'Typed');
has name => (is => 'rw', isa => 'ModelSEED::varchar', required => 1, default => '', type => 'attribute', metaclass => 'Typed');
has model_uuid => (is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed');
has regulatorymodel_uuid => (is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed');
has media_uuid => (is => 'rw', isa => 'ModelSEED::uuid', required => 1, type => 'attribute', metaclass => 'Typed');
has type => (is => 'rw', isa => 'Str', required => 1, type => 'attribute', metaclass => 'Typed');
has description => (is => 'rw', isa => 'Str', default => '', type => 'attribute', metaclass => 'Typed');
has expressionData_uuid => (is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed');
has growthConstraint => (is => 'rw', isa => 'ModelSEED::varchar', default => 'none', type => 'attribute', metaclass => 'Typed');
has thermodynamicConstraints => (is => 'rw', isa => 'ModelSEED::varchar', default => 'none', type => 'attribute', metaclass => 'Typed');
has allReversible => (is => 'rw', isa => 'Int', default => '0', type => 'attribute', metaclass => 'Typed');
has uptakeLimits => (is => 'rw', isa => 'HashRef', default => 'sub{return {};}', type => 'attribute', metaclass => 'Typed');
has numberOfSolutions => (is => 'rw', isa => 'Int', required => 1, default => '1', type => 'attribute', metaclass => 'Typed');
has geneKO => (is => 'rw', isa => 'ArrayRef', required => 1, default => 'sub{return [];}', type => 'attribute', metaclass => 'Typed');
has defaultMaxFlux => (is => 'rw', isa => 'Int', required => 1, default => '1000', type => 'attribute', metaclass => 'Typed');
has defaultMaxDrainFlux => (is => 'rw', isa => 'Int', required => 1, default => '1000', type => 'attribute', metaclass => 'Typed');
has defaultMinDrainFlux => (is => 'rw', isa => 'Int', required => 1, default => '-1000', type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has fbaObjectiveTerms => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(FBAObjectiveTerm)', metaclass => 'Typed', reader => '_fbaObjectiveTerms');
has fbaCompoundConstraints => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(FBACompoundConstraint)', metaclass => 'Typed', reader => '_fbaCompoundConstraints');
has fbaReactionConstraints => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(FBAReactionConstraint)', metaclass => 'Typed', reader => '_fbaReactionConstraints');


# LINKS:
has media => (is => 'rw', isa => 'ModelSEED::MS::Media', type => 'link(Biochemistry,media,media_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildmedia', weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }
sub _buildmedia {
    my ($self) = @_;
    return $self->getLinkedObject('Biochemistry','media',$self->media_uuid());
}


# CONSTANTS:
sub _type { return 'FBAFormulation'; }

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
            'name' => 'name',
            'default' => '',
            'type' => 'ModelSEED::varchar',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'model_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'regulatorymodel_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'name' => 'media_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'name' => 'type',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'description',
            'default' => '',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'expressionData_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'growthConstraint',
            'default' => 'none',
            'type' => 'ModelSEED::varchar',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'thermodynamicConstraints',
            'default' => 'none',
            'type' => 'ModelSEED::varchar',
            'perm' => 'rw'
          },
          {
            'len' => 255,
            'req' => 0,
            'name' => 'allReversible',
            'default' => '0',
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'uptakeLimits',
            'default' => 'sub{return {};}',
            'type' => 'HashRef',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'name' => 'numberOfSolutions',
            'default' => '1',
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'name' => 'geneKO',
            'default' => 'sub{return [];}',
            'type' => 'ArrayRef',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'name' => 'defaultMaxFlux',
            'default' => 1000,
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'name' => 'defaultMaxDrainFlux',
            'default' => 1000,
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'name' => 'defaultMinDrainFlux',
            'default' => -1000,
            'type' => 'Int',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, modDate => 1, name => 2, model_uuid => 3, regulatorymodel_uuid => 4, media_uuid => 5, type => 6, description => 7, expressionData_uuid => 8, growthConstraint => 9, thermodynamicConstraints => 10, allReversible => 11, uptakeLimits => 12, numberOfSolutions => 13, geneKO => 14, defaultMaxFlux => 15, defaultMaxDrainFlux => 16, defaultMinDrainFlux => 17};
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
            'name' => 'fbaObjectiveTerms',
            'type' => 'encompassed',
            'class' => 'FBAObjectiveTerm'
          },
          {
            'name' => 'fbaCompoundConstraints',
            'type' => 'encompassed',
            'class' => 'FBACompoundConstraint'
          },
          {
            'name' => 'fbaReactionConstraints',
            'type' => 'encompassed',
            'class' => 'FBAReactionConstraint'
          }
        ];

my $subobject_map = {fbaObjectiveTerms => 0, fbaCompoundConstraints => 1, fbaReactionConstraints => 2};
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
around 'fbaObjectiveTerms' => sub {
    my ($orig, $self) = @_;
    return $self->_build_all_objects('fbaObjectiveTerms');
};
around 'fbaCompoundConstraints' => sub {
    my ($orig, $self) = @_;
    return $self->_build_all_objects('fbaCompoundConstraints');
};
around 'fbaReactionConstraints' => sub {
    my ($orig, $self) = @_;
    return $self->_build_all_objects('fbaReactionConstraints');
};


__PACKAGE__->meta->make_immutable;
1;
