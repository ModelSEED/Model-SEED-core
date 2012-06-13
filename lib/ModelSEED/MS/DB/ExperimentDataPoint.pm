########################################################################
# ModelSEED::MS::DB::ExperimentDataPoint - This is the moose object corresponding to the ExperimentDataPoint object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::ExperimentDataPoint;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::FluxMeasurement;
use ModelSEED::MS::UptakeMeasurement;
use ModelSEED::MS::MetaboliteMeasurement;
use ModelSEED::MS::GeneMeasurement;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::Experiment', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', lazy => 1, builder => '_build_uuid', type => 'attribute', metaclass => 'Typed');
has strain_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', type => 'attribute', metaclass => 'Typed');
has media_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', type => 'attribute', metaclass => 'Typed');
has pH => (is => 'rw', isa => 'Num', printOrder => '0', type => 'attribute', metaclass => 'Typed');
has temperature => (is => 'rw', isa => 'Num', printOrder => '0', type => 'attribute', metaclass => 'Typed');
has buffers => (is => 'rw', isa => 'Str', printOrder => '0', type => 'attribute', metaclass => 'Typed');
has phenotype => (is => 'rw', isa => 'Str', printOrder => '0', type => 'attribute', metaclass => 'Typed');
has notes => (is => 'rw', isa => 'Str', printOrder => '0', type => 'attribute', metaclass => 'Typed');
has growthMeasurement => (is => 'rw', isa => 'Num', printOrder => '0', type => 'attribute', metaclass => 'Typed');
has growthMeasurementType => (is => 'rw', isa => 'Str', printOrder => '0', type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has fluxMeasurements => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(FluxMeasurement)', metaclass => 'Typed', reader => '_fluxMeasurements', printOrder => '-1');
has uptakeMeasurements => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(UptakeMeasurement)', metaclass => 'Typed', reader => '_uptakeMeasurements', printOrder => '-1');
has metaboliteMeasurements => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(MetaboliteMeasurement)', metaclass => 'Typed', reader => '_metaboliteMeasurements', printOrder => '-1');
has geneMeasurements => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(GeneMeasurement)', metaclass => 'Typed', reader => '_geneMeasurements', printOrder => '-1');


# LINKS:
has strain => (is => 'rw', isa => 'ModelSEED::MS::strains', type => 'link(Genome,strains,strain_uuid)', metaclass => 'Typed', lazy => 1, builder => '_build_strain', weak_ref => 1);
has media => (is => 'rw', isa => 'ModelSEED::MS::Media', type => 'link(Biochemistry,media,media_uuid)', metaclass => 'Typed', lazy => 1, builder => '_build_media', weak_ref => 1);


# BUILDERS:
sub _build_uuid { return Data::UUID->new()->create_str(); }
sub _build_strain {
  my ($self) = @_;
  return $self->getLinkedObject('Genome','strains',$self->strain_uuid());
}
sub _build_media {
  my ($self) = @_;
  return $self->getLinkedObject('Biochemistry','media',$self->media_uuid());
}


# CONSTANTS:
sub _type { return 'ExperimentDataPoint'; }

my $attributes = [
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'strain_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'media_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'pH',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'temperature',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'buffers',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'phenotype',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'notes',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'growthMeasurement',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'growthMeasurementType',
            'type' => 'Str',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, strain_uuid => 1, media_uuid => 2, pH => 3, temperature => 4, buffers => 5, phenotype => 6, notes => 7, growthMeasurement => 8, growthMeasurementType => 9};
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
            'printOrder' => -1,
            'name' => 'fluxMeasurements',
            'type' => 'child',
            'class' => 'FluxMeasurement'
          },
          {
            'printOrder' => -1,
            'name' => 'uptakeMeasurements',
            'type' => 'child',
            'class' => 'UptakeMeasurement'
          },
          {
            'printOrder' => -1,
            'name' => 'metaboliteMeasurements',
            'type' => 'child',
            'class' => 'MetaboliteMeasurement'
          },
          {
            'printOrder' => -1,
            'name' => 'geneMeasurements',
            'type' => 'child',
            'class' => 'GeneMeasurement'
          }
        ];

my $subobject_map = {fluxMeasurements => 0, uptakeMeasurements => 1, metaboliteMeasurements => 2, geneMeasurements => 3};
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
around 'fluxMeasurements' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('fluxMeasurements');
};
around 'uptakeMeasurements' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('uptakeMeasurements');
};
around 'metaboliteMeasurements' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('metaboliteMeasurements');
};
around 'geneMeasurements' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('geneMeasurements');
};


__PACKAGE__->meta->make_immutable;
1;
