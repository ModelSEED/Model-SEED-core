########################################################################
# ModelSEED::MS::DB::ObjectiveTerm - This is the moose object corresponding to the ObjectiveTerm object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::ObjectiveTerm;
use ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::FBAProblem', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has coefficient => (is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed');
has variable_uuid => (is => 'rw', isa => 'ModelSEED::uuid', required => 1, type => 'attribute', metaclass => 'Typed');


# LINKS:
has variable => (is => 'rw', isa => 'ModelSEED::MS::Variable', type => 'link(FBAProblem,variables,variable_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildvariable', weak_ref => 1);


# BUILDERS:
sub _buildvariable {
  my ($self) = @_;
  return $self->getLinkedObject('FBAProblem','variables',$self->variable_uuid());
}


# CONSTANTS:
sub _type { return 'ObjectiveTerm'; }

my $attributes = [
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'coefficient',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'variable_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {coefficient => 0, variable_uuid => 1};
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
