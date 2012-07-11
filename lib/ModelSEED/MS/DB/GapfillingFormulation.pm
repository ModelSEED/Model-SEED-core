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
has parent => (is => 'rw', isa => 'ModelSEED::MS::Model', weak_ref => 1, type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', lazy => 1, builder => '_build_uuid', type => 'attribute', metaclass => 'Typed');
has fbaFormulation_uuid => (is => 'rw', isa => 'ModelSEED::uuid', printOrder => '0', type => 'attribute', metaclass => 'Typed');
has balancedReactionsOnly => (is => 'rw', isa => 'Bool', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has guaranteedReactions => (is => 'rw', isa => 'ArrayRef', printOrder => '0', default => sub{return [];}, type => 'attribute', metaclass => 'Typed');
has blacklistedReactions => (is => 'rw', isa => 'ArrayRef', printOrder => '0', default => sub{return [];}, type => 'attribute', metaclass => 'Typed');
has allowableCompartments => (is => 'rw', isa => 'ArrayRef', printOrder => '0', default => sub{return [];}, type => 'attribute', metaclass => 'Typed');
has reactionActivationBonus => (is => 'rw', isa => 'Num', printOrder => '0', default => '0', type => 'attribute', metaclass => 'Typed');
has drainFluxMultiplier => (is => 'rw', isa => 'Num', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has directionalityMultiplier => (is => 'rw', isa => 'Num', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has deltaGMultiplier => (is => 'rw', isa => 'Num', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has noStructureMultiplier => (is => 'rw', isa => 'Num', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has noDeltaGMultiplier => (is => 'rw', isa => 'Num', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has biomassTransporterMultiplier => (is => 'rw', isa => 'Num', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has singleTransporterMultiplier => (is => 'rw', isa => 'Num', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has transporterMultiplier => (is => 'rw', isa => 'Num', printOrder => '0', default => '1', type => 'attribute', metaclass => 'Typed');
has modDate => (is => 'rw', isa => 'Str', printOrder => '-1', lazy => 1, builder => '_build_modDate', type => 'attribute', metaclass => 'Typed');


# ANCESTOR:
has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');


# SUBOBJECTS:
has gapfillingGeneCandidates => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(GapfillingGeneCandidate)', metaclass => 'Typed', reader => '_gapfillingGeneCandidates', printOrder => '-1');
has reactionSetMultipliers => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(ReactionSetMultiplier)', metaclass => 'Typed', reader => '_reactionSetMultipliers', printOrder => '-1');
has gapfillingSolutions => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'encompassed(GapfillingSolution)', metaclass => 'Typed', reader => '_gapfillingSolutions', printOrder => '-1');


# LINKS:
has fbaFormulation => (is => 'rw', isa => 'ModelSEED::MS::fbaFormulations', type => 'link(Model,fbaFormulations,fbaFormulation_uuid)', metaclass => 'Typed', lazy => 1, builder => '_build_fbaFormulation', weak_ref => 1);


# BUILDERS:
sub _build_uuid { return Data::UUID->new()->create_str(); }
sub _build_modDate { return DateTime->now()->datetime(); }
sub _build_fbaFormulation {
  my ($self) = @_;
  return $self->getLinkedObject('Model','fbaFormulations',$self->fbaFormulation_uuid());
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
            'name' => 'fbaFormulation_uuid',
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
          }
        ];

my $attribute_map = {uuid => 0, fbaFormulation_uuid => 1, balancedReactionsOnly => 2, guaranteedReactions => 3, blacklistedReactions => 4, allowableCompartments => 5, reactionActivationBonus => 6, drainFluxMultiplier => 7, directionalityMultiplier => 8, deltaGMultiplier => 9, noStructureMultiplier => 10, noDeltaGMultiplier => 11, biomassTransporterMultiplier => 12, singleTransporterMultiplier => 13, transporterMultiplier => 14, modDate => 15};
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
