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
has feature_uuid => (is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed');
has ortholog_uuid => (is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed');
has orthologGenome_uuid => (is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed');
has similarityScore => (is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed');
has distanceScore => (is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed');
has reactions => (is => 'rw', isa => 'ArrayRef', required => 1, default => sub{return [];}, type => 'attribute', metaclass => 'Typed');


# LINKS:
has feature => (is => 'rw', isa => 'ModelSEED::MS::Feature', type => 'link(Annotation,features,feature_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildfeature', weak_ref => 1);
has ortholog => (is => 'rw', isa => 'ModelSEED::MS::Feature', type => 'link(Annotation,features,ortholog_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildortholog', weak_ref => 1);
has orthologGenome => (is => 'rw', isa => 'ModelSEED::MS::Genome', type => 'link(Annotation,genomes,orthogenome_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildorthologGenome', weak_ref => 1);


# BUILDERS:
sub _buildfeature {
  my ($self) = @_;
  return $self->getLinkedObject('Annotation','features',$self->feature_uuid());
}
sub _buildortholog {
  my ($self) = @_;
  return $self->getLinkedObject('Annotation','features',$self->ortholog_uuid());
}
sub _buildorthologGenome {
  my ($self) = @_;
  return $self->getLinkedObject('Annotation','genomes',$self->orthogenome_uuid());
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
            'req' => 1,
            'printOrder' => 0,
            'name' => 'reactions',
            'default' => 'sub{return [];}',
            'type' => 'ArrayRef',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {feature_uuid => 0, ortholog_uuid => 1, orthologGenome_uuid => 2, similarityScore => 3, distanceScore => 4, reactions => 5};
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
