########################################################################
# ModelSEED::MS::DB::GapfillingGeneCandidate - This is the moose object corresponding to the GapfillingGeneCandidate object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::GapfillingGeneCandidate;
use ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::GapfillingFormulation', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has feature_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', type => 'attribute', metaclass => 'Typed');
has ortholog_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', type => 'attribute', metaclass => 'Typed');
has orthologGenome_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', type => 'attribute', metaclass => 'Typed');
has similarityScore => (is => 'rw', isa => 'Num', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has distanceScore => (is => 'rw', isa => 'Num', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has role_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '-1', type => 'attribute', metaclass => 'Typed');


# LINKS:
has feature => (is => 'rw', isa => 'ModelSEED::MS::Feature', type => 'link(Annotation,features,feature_uuid)', metaclass => 'Typed', lazy => 1, builder => '_build_feature', weak_ref => 1);
has ortholog => (is => 'rw', isa => 'ModelSEED::MS::Feature', type => 'link(Annotation,features,ortholog_uuid)', metaclass => 'Typed', lazy => 1, builder => '_build_ortholog', weak_ref => 1);
has orthologGenome => (is => 'rw', isa => 'ModelSEED::MS::Genome', type => 'link(Annotation,genomes,orthogenome_uuid)', metaclass => 'Typed', lazy => 1, builder => '_build_orthologGenome', weak_ref => 1);
has role => (is => 'rw', isa => 'ModelSEED::MS::Role', type => 'link(Mapping,roles,role_uuid)', metaclass => 'Typed', lazy => 1, builder => '_build_role', weak_ref => 1);


# BUILDERS:
sub _build_feature {
  my ($self) = @_;
  return $self->getLinkedObject('Annotation','features',$self->feature_uuid());
}
sub _build_ortholog {
  my ($self) = @_;
  return $self->getLinkedObject('Annotation','features',$self->ortholog_uuid());
}
sub _build_orthologGenome {
  my ($self) = @_;
  return $self->getLinkedObject('Annotation','genomes',$self->orthogenome_uuid());
}
sub _build_role {
  my ($self) = @_;
  return $self->getLinkedObject('Mapping','roles',$self->role_uuid());
}


# CONSTANTS:
sub _type { return 'GapfillingGeneCandidate'; }

my $attributes = [
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'feature_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'ortholog_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'orthologGenome_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'similarityScore',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'distanceScore',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'role_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {feature_uuid => 0, ortholog_uuid => 1, orthologGenome_uuid => 2, similarityScore => 3, distanceScore => 4, role_uuid => 5};
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
