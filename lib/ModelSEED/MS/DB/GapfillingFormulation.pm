########################################################################
# ModelSEED::MS::DB::GapfillingFormulation - This is the moose object corresponding to the GapfillingFormulation object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::GapfillingFormulation;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::GapfillingGeneCandidate;
use ModelSEED::MS::ReactionSetMultiplier;
use ModelSEED::MS::GapfillingSolution;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::MS::ModelAnalysis', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', lazy => 1, builder => '_builduuid', type => 'attribute', metaclass => 'Typed');
has media_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', type => 'attribute', metaclass => 'Typed');
has balancedReactionsOnly => (is => 'rw', isa => 'Bool', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has guaranteedReactions => (is => 'rw', isa => 'ArrayRef', printOrder => '0', default => sub{return [];}, type => 'attribute', metaclass => 'Typed');
has blacklistedReactions => (is => 'rw', isa => 'ArrayRef', printOrder => '0', default => sub{return [];}, type => 'attribute', metaclass => 'Typed');
has allowableCompartments => (is => 'rw', isa => 'ArrayRef', printOrder => '0', default => sub{return [];}, type => 'attribute', metaclass => 'Typed');
has numberOfSolutions => (is => 'rw', isa => 'Int', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has biochemistry_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');
has reactionActivationBonus => (is => 'rw', isa => 'Num', printOrder => '0', default => '0', type => 'attribute', metaclass => 'Typed');
has drainFluxMultiplier => (is => 'rw', isa => 'Num', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has directionalityMultiplier => (is => 'rw', isa => 'Num', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has deltaGMultiplier => (is => 'rw', isa => 'Num', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has noStructureMultiplier => (is => 'rw', isa => 'Num', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has noDeltaGMultiplier => (is => 'rw', isa => 'Num', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has biomassTransporterMultiplier => (is => 'rw', isa => 'Num', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has singleTransporterMultiplier => (is => 'rw', isa => 'Num', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has transporterMultiplier => (is => 'rw', isa => 'Num', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has modDate => (is => 'rw', isa => 'Str', printOrder => '-1', lazy => 1, builder => '_buildmodDate', type => 'attribute', metaclass => 'Typed');
has annotation_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has gapfillingGeneCandidates => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(GapfillingGeneCandidate)', metaclass => 'Typed', reader => '_gapfillingGeneCandidates', printOrder => '-1');
has reactionSetMultipliers => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(ReactionSetMultiplier)', metaclass => 'Typed', reader => '_reactionSetMultipliers', printOrder => '-1');
has gapfillingSolutions => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(GapfillingSolution)', metaclass => 'Typed', reader => '_gapfillingSolutions', printOrder => '-1');


# LINKS:
has media => (is => 'rw', isa => 'ModelSEED::MS::Media', type => 'link(Biochemistry,media,media_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildmedia', weak_ref => 1);
has annotation => (is => 'rw', isa => 'ModelSEED::MS::Annotation', type => 'link(Store,Annotation,annotation_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildannotation', weak_ref => 1);
has biochemistry => (is => 'rw', isa => 'ModelSEED::MS::Biochemistry', type => 'link(Store,Biochemistry,biochemistry_uuid)', metaclass => 'Typed', lazy => 1, builder => '_buildbiochemistry', weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }
sub _buildmedia {
  my ($self) = @_;
  return $self->getLinkedObject('Biochemistry','media',$self->media_uuid());
}
sub _buildannotation {
  my ($self) = @_;
  return $self->getLinkedObject('Store','Annotation',$self->annotation_uuid());
}
sub _buildbiochemistry {
  my ($self) = @_;
  return $self->getLinkedObject('Store','Biochemistry',$self->biochemistry_uuid());
}


# CONSTANTS:
sub _type { return 'GapfillingFormulation'; }

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
            'name' => 'media_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'balancedReactionsOnly',
            'default' => '1',
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'guaranteedReactions',
            'default' => 'sub{return [];}',
            'type' => 'ArrayRef',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'blacklistedReactions',
            'default' => 'sub{return [];}',
            'type' => 'ArrayRef',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'allowableCompartments',
            'default' => 'sub{return [];}',
            'type' => 'ArrayRef',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'numberOfSolutions',
            'default' => '1',
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'biochemistry_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'reactionActivationBonus',
            'default' => '0',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'drainFluxMultiplier',
            'default' => '1',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'directionalityMultiplier',
            'default' => '1',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'deltaGMultiplier',
            'default' => '1',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'noStructureMultiplier',
            'default' => '1',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'noDeltaGMultiplier',
            'default' => '1',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'biomassTransporterMultiplier',
            'default' => '1',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'singleTransporterMultiplier',
            'default' => '1',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'transporterMultiplier',
            'default' => '1',
            'type' => 'Num',
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
            'name' => 'annotation_uuid',
            'type' => 'ModelSEED::uuid',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {uuid => 0, media_uuid => 1, balancedReactionsOnly => 2, guaranteedReactions => 3, blacklistedReactions => 4, allowableCompartments => 5, numberOfSolutions => 6, biochemistry_uuid => 7, reactionActivationBonus => 8, drainFluxMultiplier => 9, directionalityMultiplier => 10, deltaGMultiplier => 11, noStructureMultiplier => 12, noDeltaGMultiplier => 13, biomassTransporterMultiplier => 14, singleTransporterMultiplier => 15, transporterMultiplier => 16, modDate => 17, annotation_uuid => 18};
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
            'name' => 'gapfillingGeneCandidates',
            'type' => 'encompassed',
            'class' => 'GapfillingGeneCandidate'
          },
          {
            'printOrder' => -1,
            'name' => 'reactionSetMultipliers',
            'type' => 'encompassed',
            'class' => 'ReactionSetMultiplier'
          },
          {
            'printOrder' => -1,
            'name' => 'gapfillingSolutions',
            'type' => 'encompassed',
            'class' => 'GapfillingSolution'
          }
        ];

my $subobject_map = {gapfillingGeneCandidates => 0, reactionSetMultipliers => 1, gapfillingSolutions => 2};
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
around 'gapfillingGeneCandidates' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('gapfillingGeneCandidates');
};
around 'reactionSetMultipliers' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('reactionSetMultipliers');
};
around 'gapfillingSolutions' => sub {
  my ($orig, $self) = @_;
  return $self->_build_all_objects('gapfillingSolutions');
};


__PACKAGE__->meta->make_immutable;
1;
