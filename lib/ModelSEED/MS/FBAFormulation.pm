########################################################################
# ModelSEED::MS::FBAFormulation - This is the moose object corresponding to the FBAFormulation object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-28T22:56:11
########################################################################
use strict;
use ModelSEED::MS::DB::FBAFormulation;
package ModelSEED::MS::FBAFormulation;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::FBAFormulation';
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
=head3 runFBA
Definition:
	ModelSEED::MS::FBAResults = ModelSEED::MS::FBAFormulation->runFBA();
Description:
	Runs the FBA study described by the fomulation and returns a typed object with the results
=cut
sub runFBA {
	my ($self) = @_;
	my $prob = $self->buildProblem({solver => "cplex"});
	$prob->printLPfile();
	my $solution = $prob->submitLPFile();
	my $results = $self->add("fbaResults",{
		name => $self->name()." results",
		fbaformulation_uuid => $self->uuid(),
		fbaformulation => $self,
		resultNotes => "",
		objectiveValue => $solution->objective(),
	});
	$results->buildFromOptSolution({LinOptSolution => $solution});
	return $results;
}
=head3 buildProblem
Definition:
	ModelSEED::MS::FBAProblem = ModelSEED::MS::Model->buildProblem();
Description:
	Builds the FBA problem
=cut
sub buildProblem {
	my ($self,$data) = @_;
	#Instantiating problem
	my $prob = ModelSEED::MS::FBAProblem->new($data);
	#Resetting dependant parameters
	if ($self->dilutionConstraints() == 1) {
		$self->decomposeReversibleFlux(1);
	}
	#Creating flux variables and mass balance constraints
	$self->createFluxVariables($prob);
	$self->createDrainFluxVariables($prob);
	$self->createMassBalanceConstraints($prob);
	#Creating use variables if called for
	if ($self->fluxUseVariables() == 1) {
		$self->createFluxUseVariables($prob);	
	}
	if ($self->drainfluxUseVariables() == 1) {
		$self->createDrainFluxUseVariables($prob);	
	}
	if ($self->drainfluxUseVariables() == 1 || $self->fluxUseVariables() == 1) {
		$prob->milp(1);
		$self->createUseVariableConstraints($prob);	
	}
	#Creating objective function
	$self->createFBAFormulationConstraints($prob);
	#Creating objective function
	$self->createObjectiveFunction($prob);
	return $prob;
}
=head3 createFluxVariables
Definition:
	void ModelSEED::MS::Model->createFluxVariables();
Description:
	Creates flux variables for all reactions in the input model
=cut
sub createFluxVariables {
	my ($self,$prob) = @_;
	#Creating flux variables
	my $rxns = $self->model()->modelreactions();
	for (my $i=0; $i < @{$rxns}; $i++) {
		my $rxn = $rxns->[$i];
		my $maxFlux = $self->defaultMaxFlux();
		my $minFlux = -1*$maxFlux;
		if ($rxns->[$i]->direction() eq ">") {
			$minFlux = 0;
		}
		if ($rxns->[$i]->direction() eq "<") {
			$maxFlux = 0;
		}
		if ($self->decomposeReversibleFlux() == 0) {
			$prob->addVariable({
				name => "f_".$rxn->id(),
				type => "flux",
				upperBound => $maxFlux,
				lowerBound => $minFlux,
				entity_uuid => $rxn->uuid()
			});
		} else {
			my $posMax = $maxFlux;
			my $posMin = 0;
			my $negMax = -1*$minFlux;
			my $negMin = 0;
			if ($posMax < 0) {
				$negMin = -1*$posMax;
				$posMax = 0;
			} elsif ($negMax < 0) {
				$posMin = -1*$negMax;
				$negMax = 0;
			}
			$prob->addVariable({
				name => "ff_".$rxns->[$i]->id(),
				type => "forflux",
				upperBound => $posMax,
				lowerBound => $posMin,
				entity_uuid => $rxns->[$i]->uuid()
			});
			$prob->addVariable({
				name => "rf_".$rxns->[$i]->id(),
				type => "revflux",
				upperBound => $negMax,
				lowerBound => $negMin,
				entity_uuid => $rxns->[$i]->uuid()
			});
		}
	}
	my $biomasses = $self->model()->biomasses();
	for (my $i=0; $i < @{$biomasses}; $i++) {
		my $bio = $biomasses->[$i];
		my $maxFlux = $self->defaultMaxFlux();
		$prob->addVariable({
			name => "f_biomass".$i,
			type => "biomassflux",
			upperBound => $maxFlux,
			lowerBound => 0,
			entity_uuid => $bio->uuid()
		});
	}
}

=head3 createDrainFluxVariables
Definition:
	Output = ModelSEED::MS::Model->createDrainFluxVariables();
	Output = {
		success => 0/1
	};
Description:
	Creates drain flux variables for all appropriate compounds in the input model
=cut
sub createDrainFluxVariables {
	my ($self,$prob) = @_;
	#Creating drain flux variables
	my $mdlcpds = $self->model()->modelcompounds();
	for (my $i=0; $i < @{$mdlcpds}; $i++) {
		my $cpd = $mdlcpds->[$i];
		if ($cpd->modelcompartment()->label() =~ m/^e/) {
			my $maxFlux = $self->defaultMaxDrainFlux();
			my $minFlux = $self->defaultMinDrainFlux();
			my $media = $self->media();
			my $mediacpds = $media->mediacompounds();
			for (my $j=0; $j < @{$mediacpds}; $j++) {
				if ($mediacpds->[$j]->compound_uuid() eq $cpd->compound_uuid()) {
					$maxFlux = $mediacpds->[$j]->maxFlux();
					$minFlux = $mediacpds->[$j]->minFlux();
				}
			}
			if ($self->decomposeReversibleDrainFlux() == 0) {
				$prob->addVariable({
					name => "df_".$cpd->id(),
					type => "drainflux",
					upperBound => $maxFlux,
					lowerBound => $minFlux,
					entity_uuid => $cpd->uuid()
				});
			} else {
				my $posMax = $maxFlux;
				my $posMin = 0;
				my $negMax = -1*$minFlux;
				my $negMin = 0;
				if ($posMax < 0) {
					$negMin = -1*$posMax;
					$posMax = 0;
				} elsif ($negMax > 0) {
					$posMin = -1*$negMax;
					$negMax = 0;
				}
				$prob->addVariable({
					name => "fdf_".$cpd->id(),
					type => "fordrainflux",
					upperBound => $posMax,
					lowerBound => $posMin,
					entity_uuid => $cpd->uuid()
				});
				$prob->addVariable({
					name => "rdf_".$cpd->id(),
					type => "revdrainflux",
					upperBound => $negMax,
					lowerBound => $negMin,
					entity_uuid => $cpd->uuid()
				});
			}
		}
	}
	my $fbaconsts = $self->fbaConstraints();
	for (my $j=0; $j < @{$fbaconsts}; $j++) {
		my $fbacpdconst = $fbaconsts->[$j];
		my $fbaconstvars = $fbacpdconst->fbaConstraintVariables();
		for (my $i=0; $i < @{$fbaconstvars}; $i++) {
			if ($fbaconstvars->[$i]->variableType() eq "drainflux" && $fbaconstvars->[$i]->variableType() eq "ModelCompound") {
				my $cpd = $self->model()->getObject("modelcompounds",$fbaconstvars->[$i]->entity_uuid());
				if ($cpd->modelcompartment()->label() !~ m/^e/) {
					my $maxFlux = -1*$self->defaultMinDrainFlux();
					my $minFlux = $self->defaultMinDrainFlux();
					if ($self->decomposeReversibleDrainFlux() == 0) {
						$prob->addVariable({
							name => "df_".$cpd->id(),
							type => "drainflux",
							upperBound => $maxFlux,
							lowerBound => $minFlux,
							entity_uuid => $cpd->uuid()
						});
					} else {
						my $posMax = $maxFlux;
						my $posMin = 0;
						my $negMax = -1*$minFlux;
						my $negMin = 0;
						if ($posMax < 0) {
							$negMin = -1*$posMax;
							$posMax = 0;
						} elsif ($negMax > 0) {
							$posMin = -1*$negMax;
							$negMax = 0;
						}
						$prob->addVariable({
							name => "fdf_".$cpd->id(),
							type => "fordrainflux",
							upperBound => $posMax,
							lowerBound => $posMin,
							entity_uuid => $cpd->uuid()
						});
						$prob->addVariable({
							name => "rdf_".$cpd->id(),
							type => "revdrainflux",
							upperBound => $negMax,
							lowerBound => $negMin,
							entity_uuid => $cpd->uuid()
						});
					}
				}
			}
		}
	}
	#Adding biomass drain flux
	my $biocpd = $self->model()->queryObject("modelcompounds",{
		name => "Biomass_c0"		
	});
	if (defined($biocpd)) {
		my $var = $prob->queryObject("variables",{
			type => "drainflux",
			entity_uuid => $biocpd->uuid()
		});	
		if (!defined($var)) {
			$var = $prob->queryObject("variables",{
				type => "revdrainflux",
				entity_uuid => $biocpd->uuid()
			});
			if (!defined($var)) {
				$prob->addVariable({
					name => "df_".$biocpd->id(),
					type => "drainflux",
					upperBound => 0,
					lowerBound => -1000,
					entity_uuid => $biocpd->uuid()
				});			
			}
		}
	}
}

=head3 createMassBalanceConstraints
Definition:
	Output = ModelSEED::MS::Model->createMassBalanceConstraints();
	Output = {
		success => 0/1
	};
Description:
	Creates mass balance constraints
=cut
sub createMassBalanceConstraints {
	my ($self,$prob) = @_;
	#Adding reaction stoichiometry
	my $rxns = $self->model()->modelreactions();
	for (my $i=0; $i < @{$rxns}; $i++) {
		my $rxn = $rxns->[$i];
		my $rgts = $rxn->modelReactionReagents();
		for (my $j=0; $j < @{$rgts}; $j++) {
			my $rgt = $rgts->[$j];
			my $const = $prob->queryObject("constraints",{
				entity_uuid => $rgt->modelcompound_uuid(),
				type => "massbalance"
			});
			if (!defined($const)) {
				$const = $prob->addConstraint({
					entity_uuid => $rgt->modelcompound_uuid(),
					name => "mb_".$rgt->modelcompound()->id(),
					type => "massbalance",
					rightHandSide => 0,
					equalityType => "=",
				});
			}
			my $fluxtypes = ["flux","forflux","revflux"];
			for (my $k=0; $k < @{$fluxtypes}; $k++) { 
				my $var = $prob->queryObject("variables",{
					entity_uuid => $rxn->uuid(),
					type => $fluxtypes->[$k]
				});
				if (defined($var)) {
					my $coefficient = $rgt->coefficient();
					if ($self->dilutionConstraints() == 1) {
						$coefficient += -0.000001;
					}
					if ($fluxtypes->[$k] eq "revflux") {
						$coefficient = -1*$coefficient;	
					}
					$const->add("constraintVariables",{
						coefficient => $coefficient,
						variable_uuid => $var->uuid()
					});
				}
			}
		}
	}
	#Adding biomass stoichiometry
	my $biomasses = $self->model()->biomasses();
	for (my $i=0; $i < @{$biomasses}; $i++) {
		my $biomasscompounds = $biomasses->[$i]->biomasscompounds();
		for (my $j=0; $j < @{$biomasscompounds}; $j++) {
			my $biocpd = $biomasscompounds->[$j];
			my $const = $prob->queryObject("constraints",{
				entity_uuid => $biocpd->modelcompound_uuid(),
				type => "massbalance"
			});
			if (!defined($const)) {
				$const = $prob->addConstraint({
					entity_uuid => $biocpd->modelcompound_uuid(),
					name => "mb_".$biocpd->modelcompound()->id(),
					type => "massbalance",
					rightHandSide => 0,
					equalityType => "=",
				});
			}
			my $var = $prob->queryObject("variables",{
				entity_uuid => $biomasses->[$i]->uuid(),
				type => "biomassflux"
			});
			if (defined($var)) {
				$const->add("constraintVariables",{
					coefficient => $biocpd->coefficient(),
					variable_uuid => $var->uuid()
				});
			} else {
				print "Variable ".$biomasses->[$i]->name()." not found!\n";	
			}
		}
	}
	#Adding drain fluxes
	my $variables = $prob->variables();
	for (my $i=0; $i < @{$variables}; $i++) {
        if (   $variables->[$i]->type() eq "drainflux"
            || $variables->[$i]->type() eq "fordrainflux"
            || $variables->[$i]->type() eq "revdrainflux")
        {
			my $coef = 1;
			if ($variables->[$i]->type() eq "revdrainflux") {
				$coef = -1;
			}
			my $const = $prob->queryObject("constraints",{
				entity_uuid => $variables->[$i]->entity_uuid(),
				type => "massbalance"
			});
			if (!defined($const)) {
				$const = $prob->addConstraint({
					entity_uuid => $variables->[$i]->entity_uuid(),
					name => "mb_".$variables->[$i]->entity_uuid(),
					type => "massbalance",
					rightHandSide => 0,
					equalityType => "=",
				});
			}
			$const->add("constraintVariables",{
				coefficient => $coef,
				variable_uuid => $variables->[$i]->uuid()
			});
		}
	}
}
=head3 createFBAFormulationConstraints
Definition:
	void ModelSEED::MS::Problem->createFBAFormulationConstraints();
Description:
	Creates FBAFormulation constraints
=cut
sub createFBAFormulationConstraints {
	my ($self,$prob) = @_;
	my $fbaConstraints = $self->fbaConstraints();
	for (my $i=0; $i < @{$fbaConstraints}; $i++) {
		my $fbaconst = $fbaConstraints->[$i];
		my $newConst = $prob->addConstraint({
			name => $fbaconst->name(),
			type => "userconstraint",
			rightHandSide => $fbaconst->rhs(),
			equalityType => $fbaconst->sign(),
		});
		my $fbaConstraintVariables = $fbaconst->fbaConstraintVariables();
		for (my $j=0; $j < @{$fbaConstraintVariables}; $j++) {
			my $constvar = $fbaConstraintVariables->[$j];
			my $var = $prob->queryObject("variables",{
				entity_uuid => $constvar->entity_uuid(),
				type => $constvar->variableType()
			});
			if (!defined($var)) {
				ModelSEED::utilities::ERROR("Constraint variable ".$constvar->entity_uuid()." ".$constvar->variableType()." not found!");
			}
			$newConst->add("constraintVariables",{
				coefficient => $constvar->coefficient(),
				variable_uuid => $var->uuid()
			});
		}
	}
}

=head3 createFluxUseVariables
Definition:
	void ModelSEED::MS::Model->createFluxUseVariables();
Description:
	Creates flux use variables for all fluxes in the input model
=cut
sub createFluxUseVariables {
	my ($self,$prob) = @_;
	my $variables = $prob->variables();
	for (my $i=0; $i < @{$variables}; $i++) {
		if ($variables->[$i]->type() eq "flux" || $variables->[$i]->type() eq "forflux" || $variables->[$i]->type() eq "revflux") {
			my $name = $variables->[$i]->name();
			$name =~ s/^f_/fu_/;
			$name =~ s/^ff_/ffu_/;
			$name =~ s/^rf_/rfu_/;
			$prob->addVariable({
				name => $name,
				type => $variables->[$i]->type()."use",
				upperBound => 1,
				lowerBound => 0,
				binary => 1,
				entity_uuid => $variables->[$i]->entity_uuid()
			});
		}
	}
}

=head3 createDrainFluxUseVariables
Definition:
	void ModelSEED::MS::Model->createDrainFluxUseVariables();
Description:
	Creates drain flux use variables for all drain fluxes in the input model
=cut
sub createDrainFluxUseVariables {
	my ($self,$prob) = @_;
	my $variables = $prob->variables();
	for (my $i=0; $i < @{$variables}; $i++) {
		if ($variables->[$i]->type() eq "drainflux" || $variables->[$i]->type() eq "fordrainflux" || $variables->[$i]->type() eq "revdrainflux") {
			my $name = $variables->[$i]->name();
			$name =~ s/^df_/dfu_/;
			$name =~ s/^fdf_/fdfu_/;
			$name =~ s/^rdf_/rdfu_/;
			$prob->addVariable({
				name => $name,
				type => $variables->[$i]->type()."use",
				upperBound => 1,
				lowerBound => 0,
				binary => 1,
				entity_uuid => $variables->[$i]->entity_uuid()
			});
		}
	}
}

=head3 createUseVariableConstraints
Definition:
	void ModelSEED::MS::Model->createUseVariableConstraints();
Description:
	Creates use variable constraints
=cut
sub createUseVariableConstraints {
	my ($self,$prob) = @_;
	my $variables = $prob->variables();
	for (my $i=0; $i < @{$variables}; $i++) {
		if ($variables->[$i]->type() =~ m/use$/) {
			my $const = $prob->addConstraint({
				entity_uuid => $variables->[$i]->entity_uuid(),
				name => $variables->[$i]->name(),
				type => "useconstraint",
				rightHandSide => 0,
				equalityType => "<",
			});
			my $type = $variables->[$i]->type();
			$type =~ s/use$//;
			my $fluxVar = $prob->queryObject("variables",{
				entity_uuid => $variables->[$i]->entity_uuid(),
				type => $type,
			});
			$const->add("constraintVariables",{
				coefficient => 1,
				variable_uuid => $fluxVar->uuid()
			});
			$const->add("constraintVariables",{
				coefficient => -1*$fluxVar->upperBound(),
				variable_uuid => $variables->[$i]->uuid()
			});
		}
	}
}
=head3 createObjectiveFunction
Definition:
	void ModelSEED::MS::Model->createObjectiveFunction();
Description:
	Creates the objective
=cut
sub createObjectiveFunction {
	my ($self,$prob) = @_;
	my $objTerms = $self->fbaObjectiveTerms();
	for (my $i=0; $i < @{$objTerms}; $i++) {
		my $term = $objTerms->[$i];
		if ($term->variableType() eq "flux") {
			my $fluxtypes = ["flux","forflux","revflux"];
			for (my $k=0; $k < @{$fluxtypes}; $k++) { 
				my $var = $prob->queryObject("variables",{
					entity_uuid => $term->entity_uuid(),
					type => $fluxtypes->[$k]
				});
				if (defined($var)) {
					my $coef = $term->coefficient();
					if ($fluxtypes->[$k] eq "revflux") {
						$coef = -1*$coef;	
					}
					$prob->add("objectiveTerms",{
						coefficient => $coef,
						variable_uuid => $var->uuid()
					});
				}
			}	
		} elsif ($term->variableType() eq "drainflux") {
			my $fluxtypes = ["drainflux","fordrainflux","revdrainflux"];
			for (my $k=0; $k < @{$fluxtypes}; $k++) { 
				my $var = $prob->queryObject("variables",{
					entity_uuid => $term->entity_uuid(),
					type => $fluxtypes->[$k]
				});
				if (defined($var)) {
					my $coef = $term->coefficient();
					if ($fluxtypes->[$k] eq "revdrainflux") {
						$coef = -1*$coef;	
					}
					$prob->add("objectiveTerms",{
						coefficient => $coef,
						variable_uuid => $var->uuid()
					});
				}
			}
		} else {
			my $var = $prob->queryObject("variables",{
				entity_uuid => $term->entity_uuid(),
				type => $term->variableType()
			});
			if (defined($var)) {
				$prob->add("objectiveTerms",{
					coefficient => $term->coefficient(),
					variable_uuid => $var->uuid()
				});
			}
		}
	}
	$prob->maximize($self->maximizeObjective());
}

__PACKAGE__->meta->make_immutable;
1;
