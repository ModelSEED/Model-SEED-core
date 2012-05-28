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
has definition => ( is => 'rw', isa => 'Str',printOrder => '3', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_builddefinition' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _builddefinition {
	my ($self) = @_;
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
=head3 runGapfilling
Definition:
	ModelSEED::MS::GapfillingSolution = ModelSEED::MS::GapfillingFormulation->runGapfilling({});
Description:
	Runs specified gapfilling analysis on specified model
=cut
sub runGapfilling {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
		"fbaformulation" => undef
	});
	if (defined($args->{fbaformulation})) {
		$self->fbaformulation($args->{fbaformulation});
		$self->fbaformulation_uuid($args->{fbaformulation}->uuid());
	}
	#Creating the database model
	my $dbmodel = $self->biochemistry()->makeDBModel({
		balancedOnly => $self->balancedReactionsOnly(),
		allowableCompartments => $self->allowableCompartments(),
		guaranteedReactions => $self->guaranteedReactions(),
		forbiddenReactions => $self->blacklistedReactions()
	});
	#Merging in the model selected for gapfilling
	my $model = $self->model();
	$dbmodel->mergeModel({
		model => $model
	});
	#Setting up the default FBAFormulation if none is provided
	if ($self->fbaformulation_uuid() eq "00000000-0000-0000-0000-000000000000") {
		my $newFormulation;
		my $formulationData = {
			name => "Default gapfilling formulation",
			model_uuid => $self->model_uuid(),
			type => "gapfilling",
			biochemistry_uuid => $self->biochemistry_uuid(),
			description => "Default gapfilling formulation",
			growthConstraint => "forcedGrowth",
			thermodynamicConstraints => 0,
			allReversible => 1,
			defaultMaxFlux => 1000,
			defaultMaxDrainFlux => 10000,
			defaultMinDrainFlux => -10000,
		};
		if (defined($self->parent())) {
			$newFormulation = $self->parent()->create("FBAFormulation",$formulationData);	
		} else {
			$newFormulation = ModelSEED::MS::FBAFormulation->new($formulationData);
		}
		$self->fbaformulation_uuid($newFormulation->uuid());
		$self->fbaformulation($newFormulation);
	}
	#Labeling all dbmodel reactions as candidates and creating objective terms
	for (my $i=0; $i < @{$dbmodel->modelreactions()}; $i++) {
		my $rxn = $dbmodel->modelreactions()->[$i];
		if (!defined($rxn->modelReactionProteins()->[0])) {
			$rxn->create("ModelReactionProtein",{
				complex_uuid => "00000000-0000-0000-0000-000000000000",
				note => "CANDIDATE"
			});
		}
		my $costs = $self->calculateReactionCosts({modelreaction => $rxn});
		if ($costs->{forwardDirection} != 0) {
			$self->fbaformulation()->create("ObjectiveTerm",{
				coefficient => $costs->{forwardDirection},
				variableType => "forfluxuse",
				variable_uuid => $rxn->uuid()
			});
		}
		if ($costs->{reverseDirection} != 0) {
			$self->fbaformulation()->create("ObjectiveTerm",{
				coefficient => $costs->{reverseDirection},
				variableType => "revfluxuse",
				variable_uuid => $rxn->uuid()
			});
		}
	}
	#Running the flux balance analysis for the gapfilling optimization problem
	my $solution = $self->fbaformulation()->runFBA();
	#Translating te solution into a gapfilling solution
	my $gfsolution = $self->create("GapfillingSolution",{
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
					$gfsolution->create("GapfillingSolutionReaction",{
						modelreaction_uuid => $rxn->uuid(),
						modelreaction => $rxn,
						direction => $direction
					});
				} elsif ($rxn->direction() eq ">") {
					$gfsolution->create("GapfillingSolutionReaction",{
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
					$gfsolution->create("GapfillingSolutionReaction",{
						modelreaction_uuid => $rxn->uuid(),
						modelreaction => $rxn,
						direction => $direction
					});
				} elsif ($rxn->direction() eq "<") {
					$gfsolution->create("GapfillingSolutionReaction",{
						modelreaction_uuid => $rxn->uuid(),
						modelreaction => $rxn,
						direction => "="
					});
				}
			}
		}
	}
	return $gfsolution;
}
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
	return {forwardDirection => 1,reverseDirection => 1};
}

__PACKAGE__->meta->make_immutable;
1;
