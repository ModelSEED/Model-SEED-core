########################################################################
# ModelSEED::MS::GapfillingFormulation - This is the moose object corresponding to the GapfillingFormulation object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-05-21T20:27:15
########################################################################
use strict;
use ModelSEED::MS::DB::GapfillingFormulation;
package ModelSEED::MS::GapfillingFormulation;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::GapfillingFormulation';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************


#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
=head3 calculateReactionCosts
Definition:
	ModelSEED::MS::GapfillingSolution = ModelSEED::MS::GapfillingFormulation->calculateReactionCosts({
		modelreaction => ModelSEED::MS::ModelReaction
	});
Description:
	Calculates the cost of adding or adjusting the reaction directionality in the model
=cut
sub calculateReactionCosts {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["modelreaction"],{});
	my $rxn = $args->{modelreaction};
	my $rcosts = 1;
	my $fcosts = 1;
	if (@{$rxn->modelReactionProteins()} > 0 && $rxn->modelReactionProteins()->[0]->note() ne "CANDIDATE") {
		if ($rxn->direction() eq ">" || $rxn->direction() eq "=") {
			$fcosts = 0;	
		}
		if ($rxn->direction() eq "<" || $rxn->direction() eq "=") {
			$rcosts = 0;
		}
	}
	if ($fcosts == 0 && $rcosts == 0) {
		return {forwardDirection => $fcosts,reverseDirection => $rcosts};
	}
	#Handling directionality multiplier
	if ($rxn->direction() eq ">") {
		$rcosts = $rcosts*$self->directionalityMultiplier();
		if ($rxn->reactioninstance()->deltaG() ne 10000000) {
			$rcosts = $rcosts*(1-$self->deltaGMultiplier()*$rxn->reactioninstance()->deltaG());
		}
	} elsif ($rxn->direction() eq "<") {
		$fcosts = $fcosts*$self->directionalityMultiplier();
		if ($rxn->reactioninstance()->deltaG() ne 10000000) {
			$fcosts = $fcosts*(1+$self->deltaGMultiplier()*$rxn->reactioninstance()->deltaG());
		}
	}
	#Checking for structure
	if ($rxn->reaction()->deltaG() eq 10000000) {
		$rcosts = $rcosts*$self->noDeltaGMultiplier();
		$fcosts = $fcosts*$self->noDeltaGMultiplier();
	}
	#Checking for transport based penalties
	if ($rxn->isTransporter() == 1) {
		$rcosts = $rcosts*$self->transporterMultiplier();
		$fcosts = $fcosts*$self->transporterMultiplier();
		if ($rxn->biomassTransporter() == 1) {
			$rcosts = $rcosts*$self->biomassTransporterMultiplier();
			$fcosts = $fcosts*$self->biomassTransporterMultiplier();
		}
		if (@{$rxn->modelReactionReagents()} <= 2) {
			$rcosts = $rcosts*$self->singleTransporterMultiplier();
			$fcosts = $fcosts*$self->singleTransporterMultiplier();
		}
	}
	#Checking for structure based penalties
	if ($rxn->missingStructure() == 1) {
		$rcosts = $rcosts*$self->noStructureMultiplier();
		$fcosts = $fcosts*$self->noStructureMultiplier();
	}		
	#Handling reactionset multipliers
	for (my $i=0; $i < @{$self->reactionSetMultipliers()}; $i++) {
		my $setMult = $self->reactionSetMultipliers()->[$i];
		my $set = $setMult->reactionset();
		if ($set->containsReaction($rxn->reaction()) == 1) {
			if ($setMult->multiplierType() eq "absolute") {
				$rcosts = $rcosts*$setMult->multiplier();
				$fcosts = $fcosts*$setMult->multiplier();
			} else {
				my $coverage = $set->modelCoverage({model=>$rxn->parent()});
				my $multiplier = $setMult->multiplier()/$coverage;
			}	
		}
	}
	return {forwardDirection => $fcosts,reverseDirection => $rcosts};
}
=head3 runGapFilling
Definition:
	ModelSEED::MS::GapfillingSolution = ModelSEED::MS::GapfillingFormulation->runGapFilling({
		model => ModelSEED::MS::Model(REQ)
	});
Description:
	Identifies the solution that gapfills the input model
=cut
sub runGapFilling {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["model"],{
		fbaFormulation => undef
	});
	my $model = $args->{model};
	my $fbaform = $args->{fbaFormulation};
	#Creating default FBAFormulation if one was not provided
	if (!defined($fbaform)) {
		my $maxDrain = 0;
		if ($self->media()->name() eq "Complete") {
			$maxDrain = 10000;
		}
		$fbaform = ModelSEED::MS::FBAFormulation->new({
			name => "Gapfilling growth test",
			model_uuid => $model->uuid(),
			model => $model,
			media_uuid => $self->media_uuid(),
			media => $self->media(),
			type => "singlegrowth",
			biochemistry_uuid => $self->biochemistry_uuid(),
			biochemistry => $self->biochemistry(),
			description => "Gapfilling growth test",
			growthConstraint => "none",
			thermodynamicConstraints => "none",
			allReversible => 0,
			defaultMaxFlux => 1000,
			defaultMaxDrainFlux => $maxDrain,
			defaultMinDrainFlux => -10000,
			decomposeReversibleFlux => 0,
			decomposeReversibleDrainFlux => 0,
			fluxUseVariables => 0,
			drainfluxUseVariables => 0,
			maximizeObjective => 1,
			fbaObjectiveTerms => [{
				coefficient => 1,
				entityType => "Biomass",
				variableType => "biomassflux",
				entity_uuid => $model->biomasses()->[0]->uuid()
			}]			
		});
	}
	#Testing if the object function is already greater than zero
	print "Testing for zero objective!\n";
	my $fbasolution = $fbaform->runFBA();
	if ($fbasolution->objectiveValue() > 0.0000001) {
		print "Objective is already greater than zero. No gapfilling needed!\n";
		return undef;
	}
	print "Objective is zero. Proceeding with gapfilling!\n";
	#Creating the database model
	my $dbmodel = $self->biochemistry()->makeDBModel({
		balancedOnly => $self->balancedReactionsOnly(),
		allowableCompartments => $self->allowableCompartments(),
		guaranteedReactions => $self->guaranteedReactions(),
		forbiddenReactions => $self->blacklistedReactions()
	});
	#Merging in the model selected for gapfilling
	$dbmodel->mergeModel({
		model => $model
	});
	#Creating gapfilling FBAFormulation
	my $gffbaform = ModelSEED::MS::FBAFormulation->new({
		name => "Gapfilling simulation",
		model_uuid => $dbmodel->uuid(),
		model => $dbmodel,
		media_uuid => $self->media_uuid(),
		media => $self->media(),
		type => "gapfilling",
		biochemistry_uuid => $self->biochemistry_uuid(),
		biochemistry => $self->biochemistry(),
		description => "Gapfilling simulation",
		growthConstraint => "none",
		thermodynamicConstraints => "none",
		allReversible => 1,
		defaultMaxFlux => 1000,
		defaultMaxDrainFlux => $fbaform->defaultMaxDrainFlux(),
		defaultMinDrainFlux => -10000,
		decomposeReversibleFlux => 1,
		decomposeReversibleDrainFlux => 0,
		fluxUseVariables => 1,
		drainfluxUseVariables => 0,
		maximizeObjective => 0,			
	});
	my $typesToAttribute = {
		ModelReaction => "modelreactions",
		ModelCompound => "modelcompounds",
		Biomass => "biomasses"
	};
	#Copying all constraints from previous FBAFormulation
	for (my $i=0; $i < @{$fbaform->fbaConstraints()}; $i++) {
		my $oldConst = $fbaform->fbaConstraints()->[$i];
		my $const = $gffbaform->add("fbaConstraints",{
			name => $oldConst->name(),
			rhs => $oldConst->rhs(),
			sign => $oldConst->sign()
		});
		for (my $j=0; $j < @{$oldConst->fbaConstraintVariables()}; $j++) {
			my $term = $fbaform->fbaObjectiveTerms()->[$j];
			my $obj = $dbmodel->queryObject($typesToAttribute->{$term->entityType()},{mapped_uuid => $term->entity_uuid()});
			$const->add("fbaConstraintVariables",{
				entity_uuid => $obj->entity_uuid(),
				entityType => $term->entityType(),
				variableType => $term->variableType(),
				coefficient => $term->coefficient()
			});
		}
	}
	#Making a constraint forcing the previous objective to be greater than zero
	my $const = $gffbaform->add("fbaConstraints",{
		name => "Objective constraint",
		rhs => 0.01,
		sign => ">"
	});
	for (my $i=0; $i < @{$fbaform->fbaObjectiveTerms()}; $i++) {
		my $term = $fbaform->fbaObjectiveTerms()->[$i];
		my $obj = $dbmodel->queryObject($typesToAttribute->{$term->entityType()},{mapped_uuid => $term->entity_uuid()});
		$const->add("fbaConstraintVariables",{
			entity_uuid => $obj->entity_uuid(),
			entityType => $term->entityType(),
			variableType => $term->variableType(),
			coefficient => $term->coefficient()
		});
	}
	#Labeling all dbmodel reactions as candidates and creating objective terms
	for (my $i=0; $i < @{$dbmodel->modelreactions()}; $i++) {
		my $rxn = $dbmodel->modelreactions()->[$i];
		if (!defined($rxn->modelReactionProteins()->[0])) {
			$rxn->add("modelReactionProteins",{
				complex_uuid => "00000000-0000-0000-0000-000000000000",
				note => "CANDIDATE"
			});
		}
		my $costs = $self->calculateReactionCosts({modelreaction => $rxn});
		if ($costs->{forwardDirection} != 0) {
			$gffbaform->add("objectiveTerms",{
				entity_uuid => $rxn->uuid(),
				entityType => "Reaction",
				variableType => "forfluxuse",
				coefficient => $costs->{forwardDirection}
			});
		}
		if ($costs->{reverseDirection} != 0) {
			$gffbaform->add("objectiveTerms",{
				entity_uuid => $rxn->uuid(),
				entityType => "Reaction",
				variableType => "revfluxuse",
				coefficient => $costs->{reverseDirection}
			});
		}
	}
	#Running the flux balance analysis for the gapfilling optimization problem
	my $solution = $gffbaform->runFBA();
	#Translating te solution into a gapfilling solution
	my $gfsolution = $self->add("gapfillingSolutions",{
		solutionCost => $solution->objectiveValue()
	});
	for (my $i=0; $i < @{$solution->fbaReactionVariables()}; $i++) {
		my $var = $solution->fbaReactionVariables()->[$i];
		if ($var->variableType() eq "flux") {
			my $rxn = $var->modelreaction();
			if ($var->value() < -0.0000001) {
				if (defined($rxn->modelReactionProteins()->[0]) && $rxn->modelReactionProteins()->[0]->note() eq "CANDIDATE") {
					my $direction = "<";
					if ($rxn->direction() ne $direction) {
						$direction = "=";
					}
					$gfsolution->add("gapfillingSolutionReactions",{
						modelreaction_uuid => $rxn->uuid(),
						modelreaction => $rxn,
						direction => $direction
					});
				} elsif ($rxn->direction() eq ">") {
					$gfsolution->add("gapfillingSolutionReactions",{
						modelreaction_uuid => $rxn->uuid(),
						modelreaction => $rxn,
						direction => "="
					});
				}
			} elsif ($var->value() > 0.0000001) {
				if (defined($rxn->modelReactionProteins()->[0]) && $rxn->modelReactionProteins()->[0]->note() eq "CANDIDATE") {
					my $direction = ">";
					if ($rxn->direction() ne $direction) {
						$direction = "=";
					}
					$gfsolution->add("gapfillingSolutionReactions",{
						modelreaction_uuid => $rxn->uuid(),
						modelreaction => $rxn,
						direction => $direction
					});
				} elsif ($rxn->direction() eq "<") {
					$gfsolution->add("gapfillingSolutionReactions",{
						modelreaction_uuid => $rxn->uuid(),
						modelreaction => $rxn,
						direction => "="
					});
				}
			}
		}
	}
	return $solution;
}

__PACKAGE__->meta->make_immutable;
1;
