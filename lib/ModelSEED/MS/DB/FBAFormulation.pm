########################################################################
# ModelSEED::MS::DB::FBAFormulation - This is the moose object corresponding to the FBAFormulation object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::FBAFormulation;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::FBAObjectiveTerm;
use ModelSEED::MS::FBAConstraint;
use ModelSEED::MS::FBAReactionBound;
use ModelSEED::MS::FBACompoundBound;
use ModelSEED::MS::FBAResult;
use ModelSEED::MS::FBAPhenotypeSimulation;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::Model', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', lazy => 1, builder => '_build_uuid', type => 'attribute', metaclass => 'Typed');
has modDate => (is => 'rw', isa => 'Str', printOrder => '-1', lazy => 1, builder => '_build_modDate', type => 'attribute', metaclass => 'Typed');
has regulatorymodel_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', type => 'attribute', metaclass => 'Typed');
has media_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');
has fva => (is => 'rw', isa => 'Bool', printOrder => '0', default => '0', type => 'attribute', metaclass => 'Typed');
has comboDeletions => (is => 'rw', isa => 'Int', printOrder => '0', default => '0', type => 'attribute', metaclass => 'Typed');
has fluxMinimization => (is => 'rw', isa => 'Bool', printOrder => '0', default => '0', type => 'attribute', metaclass => 'Typed');
has findMinimalMedia => (is => 'rw', isa => 'Bool', printOrder => '0', default => '0', type => 'attribute', metaclass => 'Typed');
has notes => (is => 'rw', isa => 'Str', printOrder => '0', default => '', type => 'attribute', metaclass => 'Typed');
has expressionData_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', type => 'attribute', metaclass => 'Typed');
has objectiveConstraintFraction => (is => 'rw', isa => 'ModelSEED::varchar', printOrder => '0', default => 'none', type => 'attribute', metaclass => 'Typed');
has allReversible => (is => 'rw', isa => 'Int', printOrder => '0', default => '0', type => 'attribute', metaclass => 'Typed');
has defaultMaxFlux => (is => 'rw', isa => 'Int', printOrder => '0', required => 1, default => '1000', type => 'attribute', metaclass => 'Typed');
has defaultMaxDrainFlux => (is => 'rw', isa => 'Int', printOrder => '0', required => 1, default => '1000', type => 'attribute', metaclass => 'Typed');
has defaultMinDrainFlux => (is => 'rw', isa => 'Int', printOrder => '0', required => 1, default => '-1000', type => 'attribute', metaclass => 'Typed');
has maximizeObjective => (is => 'rw', isa => 'Bool', printOrder => '0', required => 1, default => '1', type => 'attribute', metaclass => 'Typed');
has decomposeReversibleFlux => (is => 'rw', isa => 'Bool', printOrder => '0', default => '0', type => 'attribute', metaclass => 'Typed');
has decomposeReversibleDrainFlux => (is => 'rw', isa => 'Bool', printOrder => '0', default => '0', type => 'attribute', metaclass => 'Typed');
has fluxUseVariables => (is => 'rw', isa => 'Bool', printOrder => '0', default => '0', type => 'attribute', metaclass => 'Typed');
has drainfluxUseVariables => (is => 'rw', isa => 'Bool', printOrder => '0', default => '0', type => 'attribute', metaclass => 'Typed');
has geneKO_uuids => (is => 'rw', isa => 'ArrayRef', printOrder => '0', default => sub{return [];}, type => 'attribute', metaclass => 'Typed');
has reactionKO_uuids => (is => 'rw', isa => 'ArrayRef', printOrder => '0', default => sub{return [];}, type => 'attribute', metaclass => 'Typed');
has parameters => (is => 'rw', isa => 'HashRef', printOrder => '0', default => sub{return {};}, type => 'attribute', metaclass => 'Typed');
has uptakeLimits => (is => 'rw', isa => 'HashRef', printOrder => '0', default => sub{return {};}, type => 'attribute', metaclass => 'Typed');
has numberOfSolutions => (is => 'rw', isa => 'Int', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has simpleThermoConstraints => (is => 'rw', isa => 'Bool', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has thermodynamicConstraints => (is => 'rw', isa => 'Bool', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has noErrorThermodynamicConstraints => (is => 'rw', isa => 'Bool', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has minimizeErrorThermodynamicConstraints => (is => 'rw', isa => 'Bool', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has fbaObjectiveTerms => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(FBAObjectiveTerm)', metaclass => 'Typed', reader => '_fbaObjectiveTerms', printOrder => '-1');
has fbaConstraints => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(FBAConstraint)', metaclass => 'Typed', reader => '_fbaConstraints', printOrder => '-1');
has fbaReactionBounds => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(FBAReactionBound)', metaclass => 'Typed', reader => '_fbaReactionBounds', printOrder => '-1');
has fbaCompoundBounds => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(FBACompoundBound)', metaclass => 'Typed', reader => '_fbaCompoundBounds', printOrder => '-1');
has fbaResults => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(FBAResult)', metaclass => 'Typed', reader => '_fbaResults', printOrder => '-1');
has fbaPhenotypeSimulations => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(FBAPhenotypeSimulation)', metaclass => 'Typed', reader => '_fbaPhenotypeSimulations', printOrder => '-1');


# LINKS:
has media => (is => 'rw', isa => 'ModelSEED::MS::Media', type => 'link(Biochemistry,media,media_uuid)', metaclass => 'Typed', lazy => 1, builder => '_build_media', weak_ref => 1);
has geneKOs => (is => 'rw', isa => 'ModelSEED::MS::Feature', type => 'link(Annotation,features,geneKO_uuids)', metaclass => 'Typed', lazy => 1, builder => '_build_geneKOs', weak_ref => 1);
has reactionKOs => (is => 'rw', isa => 'ModelSEED::MS::Media', type => 'link(Biochemistry,media,reactionKO)', metaclass => 'Typed', lazy => 1, builder => '_build_reactionKOs', weak_ref => 1);


# BUILDERS:
sub _build_uuid { return Data::UUID->new()->create_str(); }
sub _build_modDate { return DateTime->now()->datetime(); }
sub _build_media {
  my ($self) = @_;
  return $self->getLinkedObject('Biochemistry','media',$self->media_uuid());
}
sub _build_geneKOs {
  my ($self) = @_;
  return $self->getLinkedObject('Annotation','features',$self->geneKO_uuids());
}
sub _build_reactionKOs {
  my ($self) = @_;
  return $self->getLinkedObject('Biochemistry','media',$self->reactionKO());
}


# CONSTANTS:
sub _type { return 'FBAFormulation'; }

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
            'printOrder' => -1,
            'name' => 'modDate',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'regulatorymodel_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'media_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'printOrder' => 0,
            'name' => 'fva',
            'default' => 0,
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'printOrder' => 0,
            'name' => 'comboDeletions',
            'default' => 0,
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'printOrder' => 0,
            'name' => 'fluxMinimization',
            'default' => 0,
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'printOrder' => 0,
            'name' => 'findMinimalMedia',
            'default' => 0,
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'notes',
            'default' => '',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'expressionData_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'objectiveConstraintFraction',
            'default' => 'none',
            'type' => 'ModelSEED::varchar',
            'perm' => 'rw'
          },
          {
            'len' => 255,
            'req' => 0,
            'printOrder' => 0,
            'name' => 'allReversible',
            'default' => '0',
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'defaultMaxFlux',
            'default' => 1000,
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'defaultMaxDrainFlux',
            'default' => 1000,
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'defaultMinDrainFlux',
            'default' => -1000,
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'maximizeObjective',
            'default' => 1,
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'len' => 32,
            'req' => 0,
            'printOrder' => 0,
            'name' => 'decomposeReversibleFlux',
            'default' => 0,
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'len' => 32,
            'req' => 0,
            'printOrder' => 0,
            'name' => 'decomposeReversibleDrainFlux',
            'default' => 0,
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'len' => 32,
            'req' => 0,
            'printOrder' => 0,
            'name' => 'fluxUseVariables',
            'default' => 0,
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'len' => 32,
            'req' => 0,
            'printOrder' => 0,
            'name' => 'drainfluxUseVariables',
            'default' => 0,
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'geneKO_uuids',
            'default' => 'sub{return [];}',
            'type' => 'ArrayRef',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'reactionKO_uuids',
            'default' => 'sub{return [];}',
            'type' => 'ArrayRef',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'parameters',
            'default' => 'sub{return {};}',
            'type' => 'HashRef',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'uptakeLimits',
            'default' => 'sub{return {};}',
            'type' => 'HashRef',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'numberOfSolutions',
            'default' => 1,
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'simpleThermoConstraints',
            'default' => 1,
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'thermodynamicConstraints',
            'default' => 1,
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'noErrorThermodynamicConstraints',
            'default' => 1,
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'minimizeErrorThermodynamicConstraints',
            'default' => 1,
            'type' => 'Bool',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, modDate => 1, regulatorymodel_uuid => 2, media_uuid => 3, fva => 4, comboDeletions => 5, fluxMinimization => 6, findMinimalMedia => 7, notes => 8, expressionData_uuid => 9, objectiveConstraintFraction => 10, allReversible => 11, defaultMaxFlux => 12, defaultMaxDrainFlux => 13, defaultMinDrainFlux => 14, maximizeObjective => 15, decomposeReversibleFlux => 16, decomposeReversibleDrainFlux => 17, fluxUseVariables => 18, drainfluxUseVariables => 19, geneKO_uuids => 20, reactionKO_uuids => 21, parameters => 22, uptakeLimits => 23, numberOfSolutions => 24, simpleThermoConstraints => 25, thermodynamicConstraints => 26, noErrorThermodynamicConstraints => 27, minimizeErrorThermodynamicConstraints => 28};
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
            'name' => 'fbaObjectiveTerms',
            'type' => 'encompassed',
            'class' => 'FBAObjectiveTerm'
          },
          {
            'printOrder' => -1,
            'name' => 'fbaConstraints',
            'type' => 'encompassed',
            'class' => 'FBAConstraint'
          },
          {
            'printOrder' => -1,
            'name' => 'fbaReactionBounds',
            'type' => 'encompassed',
            'class' => 'FBAReactionBound'
          },
          {
            'printOrder' => -1,
            'name' => 'fbaCompoundBounds',
            'type' => 'encompassed',
            'class' => 'FBACompoundBound'
          },
          {
            'printOrder' => -1,
            'name' => 'fbaResults',
            'type' => 'encompassed',
            'class' => 'FBAResult'
          },
          {
            'printOrder' => -1,
            'name' => 'fbaPhenotypeSimulations',
            'type' => 'encompassed',
            'class' => 'FBAPhenotypeSimulation'
          }
        ];

my $subobject_map = {fbaObjectiveTerms => 0, fbaConstraints => 1, fbaReactionBounds => 2, fbaCompoundBounds => 3, fbaResults => 4, fbaPhenotypeSimulations => 5};
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
around 'fbaConstraints' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('fbaConstraints');
};
around 'fbaReactionBounds' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('fbaReactionBounds');
};
around 'fbaCompoundBounds' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('fbaCompoundBounds');
};
around 'fbaResults' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('fbaResults');
};
around 'fbaPhenotypeSimulations' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('fbaPhenotypeSimulations');
};


__PACKAGE__->meta->make_immutable;
1;
