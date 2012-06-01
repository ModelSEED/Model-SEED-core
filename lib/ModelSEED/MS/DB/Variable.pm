########################################################################
# ModelSEED::MS::DB::Variable - This is the moose object corresponding to the Variable object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Variable;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::ConstraintVariable;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::FBAProblem', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', lazy => 1, builder => '_builduuid', type => 'attribute', metaclass => 'Typed');
has name => (is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed');
has type => (is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed');
has binary => (is => 'rw', isa => 'Bool', default => '0', type => 'attribute', metaclass => 'Typed');
has start => (is => 'rw', isa => 'Num', required => 1, default => '0', type => 'attribute', metaclass => 'Typed');
has upperBound => (is => 'rw', isa => 'Num', required => 1, type => 'attribute', metaclass => 'Typed');
has lowerBound => (is => 'rw', isa => 'Num', required => 1, type => 'attribute', metaclass => 'Typed');
has min => (is => 'rw', isa => 'Num', required => 1, type => 'attribute', metaclass => 'Typed');
has max => (is => 'rw', isa => 'Num', required => 1, type => 'attribute', metaclass => 'Typed');
has value => (is => 'rw', isa => 'Num', required => 1, default => '0', type => 'attribute', metaclass => 'Typed');
has entity_uuid => (is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed');
has index => (is => 'rw', isa => 'Int', required => 1, type => 'attribute', metaclass => 'Typed');
has primal => (is => 'rw', isa => 'Bool', required => 1, default => '1', type => 'attribute', metaclass => 'Typed');
has dualConstraint_uuid => (is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed');
has upperBoundDualVariable_uuid => (is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed');
has lowerBoundDualVariable_uuid => (is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has constraintVariables => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(ConstraintVariable)', metaclass => 'Typed', reader => '_constraintVariables');


# LINKS:
has dualConstraint => (is => 'rw', isa => 'ModelSEED::MS::Constraint', type => 'link(FBAProblem,constraints,dualConstraint_uuid)', metaclass => 'Typed', lazy => 1, builder => '_builddualConstraint', weak_ref => 1);
has upperBoundDualVariable => (is => 'rw', isa => 'ModelSEED::MS::Constraint', type => 'link(FBAProblem,constraints,upperBoundDualVariable_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildupperBoundDualVariable', weak_ref => 1);
has lowerBoundDualVariable => (is => 'rw', isa => 'ModelSEED::MS::Constraint', type => 'link(FBAProblem,constraints,lowerBoundDualVariable_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildlowerBoundDualVariable', weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _builddualConstraint {
    my ($self) = @_;
    return $self->getLinkedObject('FBAProblem','constraints',$self->dualConstraint_uuid());
}
sub _buildupperBoundDualVariable {
    my ($self) = @_;
    return $self->getLinkedObject('FBAProblem','constraints',$self->upperBoundDualVariable_uuid());
}
sub _buildlowerBoundDualVariable {
    my ($self) = @_;
    return $self->getLinkedObject('FBAProblem','constraints',$self->lowerBoundDualVariable_uuid());
}


# CONSTANTS:
sub _type { return 'Variable'; }

my $attributes = [
          {
            'req' => 0,
            'name' => 'uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'name',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'type',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'binary',
            'default' => 0,
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'name' => 'start',
            'default' => 0,
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'name' => 'upperBound',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'name' => 'lowerBound',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'name' => 'min',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'name' => 'max',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'name' => 'value',
            'default' => 0,
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'entity_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'name' => 'index',
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'len' => 1,
            'req' => 1,
            'name' => 'primal',
            'default' => 1,
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'dualConstraint_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'upperBoundDualVariable_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'name' => 'lowerBoundDualVariable_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, name => 1, type => 2, binary => 3, start => 4, upperBound => 5, lowerBound => 6, min => 7, max => 8, value => 9, entity_uuid => 10, index => 11, primal => 12, dualConstraint_uuid => 13, upperBoundDualVariable_uuid => 14, lowerBoundDualVariable_uuid => 15};
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
            'name' => 'constraintVariables',
            'type' => 'child',
            'class' => 'ConstraintVariable'
          }
        ];

my $subobject_map = {constraintVariables => 0};
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
around 'constraintVariables' => sub {
    my ($orig, $self) = @_;
    return $self->_build_all_objects('constraintVariables');
};


__PACKAGE__->meta->make_immutable;
1;
