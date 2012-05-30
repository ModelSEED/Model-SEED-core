########################################################################
# ModelSEED::MS::Biochemistry - This is the moose object corresponding to the Biochemistry object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use ModelSEED::MS::DB::Biochemistry;
package ModelSEED::MS::Biochemistry;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::Biochemistry';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has definition => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_builddefinition' );


#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _builddefinition {
	my ($self) = @_;
	return $self->createEquation({format=>"name",hashed=>0});
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
=head3 makeDBModel
Definition:
	ModelSEED::MS::ModelReaction = ModelSEED::MS::Biochemistry->makeDBModel({
		balancedOnly => 1,
		forbiddenCompartments => [],
		guaranteedReactions => [],
		forbiddenReactions => [],
		annotation_uuid => "00000000-0000-0000-0000-000000000000",
		mapping_uuid => "00000000-0000-0000-0000-000000000000",
	});
Description:
	Creates a model that has every reaction instance in the database that pass through the specified filters
=cut
sub makeDBModel {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
		balancedOnly => 1,
		allowableCompartments => [],
		guaranteedReactions => [],
		forbiddenReactions => [],
		annotation_uuid => "00000000-0000-0000-0000-000000000000",
		mapping_uuid => "00000000-0000-0000-0000-000000000000",
	});
	my $mdl = ModelSEED::MS::Model->new({
		id => $self->id().".model",
		version => 0,
		type => "dbmodel",
		name => $self->name().".model",
		growth => 0,
		status => "Built from database",
		current => 1,
		mapping_uuid => $args->{mapping_uuid},
		biochemistry_uuid => $self->uuid(),
		biochemistry => $self,
		annotation_uuid => $args->{annotation_uuid}
	});
	my $hashes;
	for (my $i=0; $i < @{$args->{guaranteedReactions}}; $i++) {
		$hashes->{guaranteed}->{$args->{guaranteedReactions}->[$i]} = 1;
	}
	for (my $i=0; $i < @{$args->{forbiddenReactions}}; $i++) {
		$hashes->{forbidden}->{$args->{forbiddenReactions}->[$i]} = 1;
	}
	for (my $i=0; $i < @{$args->{allowableCompartments}}; $i++) {
		$hashes->{allowcomp}->{$args->{allowableCompartments}->[$i]} = 1;
	}
	for (my $i=0; $i < @{$self->reactioninstances()}; $i++) {
		my $rxn = $self->reactioninstances()->[$i];
		if (!defined($hashes->{forbidden}->{$rxn->uuid()})) {
			my $add = 1;
			if (!defined($hashes->{guaranteed}->{$rxn->uuid()})) {
				if (!defined($hashes->{allowcomp}->{$rxn->compartment_uuid()})) {
					$add = 0;	
				}
				for (my $j=0; $j < @{$rxn->transports()};$j++) {
					if (!defined($hashes->{allowcomp}->{$rxn->transports()->[$j]->compartment_uuid()})) {
						$add = 0;
						last;
					}
				}
				if ($args->{balancedOnly} == 1 && $rxn->balanced() == 0) {
					$add = 0;
				}
			}
			if ($add == 1) {
				my $mdl->addReactionInstanceToModel({
					reactionInstance => $rxn,
				});
			}
		}
	}
	return $mdl;
}
=head3 findCreateEquivalentCompartment
Definition:
	void ModelSEED::MS::Biochemistry->findCreateEquivalentCompartment({
		compartment => ModelSEED::MS::Compartment(REQ),
		create => 0/1(1)
	});
Description:
	Search for an equivalent comparment for the input biochemistry compartment
=cut
sub findCreateEquivalentCompartment {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["compartment"],{create => 1});
	my $incomp = $args->{compartment};
	my $outcomp = $self->getObject("Compartment",{
		name => $incomp->name()
	});
	if (!defined($outcomp) && $args->{create} == 1) {
		$outcomp = $self->biochemistry()->create("Compartment",{
			id => $incomp->id(),
			name => $incomp->name(),
			hierarchy => $incomp->hierarchy()
		});
	}
	#$incomp->id($outcomp->uuid());
	return $outcomp;
}
=head3 findCreateEquivalentCompound
Definition:
	void ModelSEED::MS::Biochemistry->findCreateEquivalentCompound({
		compound => ModelSEED::MS::Compound(REQ),
		create => 0/1(1)
	});
Description:
	Search for an equivalent compound for the input biochemistry compound
=cut
sub findCreateEquivalentCompound {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["compound"],{create => 1});
	my $incpd = $args->{compound};
	my $outcpd = $self->getObject("Compound",{
		name => $incpd->name()
	});
	if (!defined($outcpd) && $args->{create} == 1) {
		$outcpd = $self->biochemistry()->create("Compound",{
			name => $incpd->name(),
			abbreviation => $incpd->abbreviation(),
			unchargedFormula => $incpd->unchargedFormula(),
			formula => $incpd->formula(),
			mass => $incpd->mass(),
			defaultCharge => $incpd->defaultCharge(),
			deltaG => $incpd->deltaG(),
			deltaGErr => $incpd->deltaGErr(),
		});
		for (my $i=0; $i < @{$incpd->structures()}; $i++) {
			my $cpdstruct = $incpd->structures()->[$i];
			$outcpd->create("CompoundStructure",$cpdstruct->serializeToDB());
		}
		for (my $i=0; $i < @{$incpd->pks()}; $i++) {
			my $cpdpk = $incpd->pks()->[$i];
			$outcpd->create("CompoundPk",$cpdpk->serializeToDB());
		}
	}
	$incpd->id($outcpd->uuid());
	return $outcpd;
}
=head3 findCreateEquivalentReaction
Definition:
	void ModelSEED::MS::Biochemistry->findCreateEquivalentReaction({
		reaction => ModelSEED::MS::Reaction(REQ),
		create => 0/1(1)
	});
Description:
	Search for an equivalent reaction for the input biochemistry reaction
=cut
sub findCreateEquivalentReaction {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["reaction"],{create => 1});
	my $inrxn = $args->{reaction};
	my $outrxn = $self->getObject("Reaction",{
		definition => $inrxn->definition()
	});
	if (!defined($outrxn) && $args->{create} == 1) {
		$outrxn = $self->biochemistry()->create("Reaction",{
			name => $inrxn->name(),
			abbreviation => $inrxn->abbreviation(),
			reversibility => $inrxn->reversibility(),
			thermoReversibility => $inrxn->thermoReversibility(),
			defaultProtons => $inrxn->defaultProtons(),
			status => $inrxn->status(),
			deltaG => $inrxn->deltaG(),
			deltaGErr => $inrxn->deltaGErr(),
		});
		for (my $i=0; $i < @{$inrxn->reagents()}; $i++) {
			my $rgt = $inrxn->reagents()->[$i];
			my $cpd = $self->biochemistry()->findCreateEquivalentCompound({
				compound => $rgt->compound(),
				create => 1
			});
			$outrxn->create("Reagent",{
				compound_uuid => $cpd->uuid(),
				coefficient => $rgt->coefficient(),
				cofactor => $rgt->cofactor(),
				compartmentIndex => $rgt->compartmentIndex(),
			});
		}
	}
	$inrxn->id($outrxn->uuid());
	return $outrxn;
}

__PACKAGE__->meta->make_immutable;
1;
