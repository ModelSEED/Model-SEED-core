########################################################################
# ModelSEED::MS::FBAProblem - This is the moose object corresponding to the FBAProblem object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-05-05T02:39:57
########################################################################
use strict;
use ModelSEED::MS::DB::FBAProblem;
package ModelSEED::MS::FBAProblem;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::FBAProblem';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has model => ( is => 'rw', isa => 'ModelSEED::MS::Model',printOrder => '-1', type => 'msdata', metaclass => 'Typed');
has fbaFormulation => ( is => 'rw', isa => 'ModelSEED::MS::FBAFormulation',printOrder => '-1', type => 'msdata', metaclass => 'Typed');
has directory => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_builddirectory');
has solver => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed',default => 'glpk');

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _builddirectory {
	my ($self) = @_;
	return File::Temp::tempdir(DIR => ModelSEED::utilities::MODELSEEDCORE()."data/fbafiles/")."/";
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************


#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
=head3 clearProblem
Definition:
	Output = ModelSEED::MS::Model->clearProblem();
	Output = {
		success => 0/1
	};
Description:
	Builds the FBA problem
=cut
sub clearProblem {
	my ($self) = @_;
	$self->variables([]);
	$self->constraints([]);
	$self->objectiveTerms([]);
}

=head3 buildProblem
Definition:
	Output = ModelSEED::MS::Model->buildProblem();
	Output = {
		success => 0/1
	};
Description:
	Builds the FBA problem
=cut
sub buildProblem {
	my ($self) = @_;
	$self->clearProblem();
	#Creating flux variables and mass balance constraints
	$self->createFluxVariables();
	$self->createDrainFluxVariables();
	$self->createMassBalanceConstraints();
	#Creating use variables if called for
	if ($self->fluxUseVariables() == 1) {
		$self->createFluxUseVariables();	
	}
	if ($self->drainfluxUseVariables() == 1) {
		$self->createDrainFluxUseVariables();	
	}
	if ($self->drainfluxUseVariables() == 1 || $self->fluxUseVariables() == 1) {
		$self->milp(1);
		$self->createUseVariableConstraints();	
	}
	#Creating objective function
	$self->createObjectiveFunction();
}

=head3 createObjectiveFunction
Definition:
	Output = ModelSEED::MS::Model->createObjectiveFunction();
	Output = {
		success => 0/1
	};
Description:
	Builds the FBA problem
=cut
sub createObjectiveFunction {
	my ($self) = @_;
	$self->objectiveTerms([]);
	for (my $i=0; $i < @{$self->fbaFormulation()->fbaObjectiveTerms()}; $i++) {
		my $term = $self->fbaFormulation()->fbaObjectiveTerms()->[$i];
		if ($term->variableType() eq "flux") {
			my $fluxtypes = ["flux","forflux","revflux"];
			for (my $k=0; $k < @{$fluxtypes}; $k++) { 
				my $var = $self->getObject("Variable",{
					entity_uuid => $term->variable_uuid(),
					type => $fluxtypes->[$k]
				});
				if (defined($var)) {
					$self->create("ObjectiveTerm",{
						coefficient => $term->coefficient(),
						variable_uuid => $var->uuid()
					});
				}
			}
		} elsif ($term->variableType() eq "drainflux") {
			my $fluxtypes = ["drainflux","fordrainflux","revdrainflux"];
			for (my $k=0; $k < @{$fluxtypes}; $k++) { 
				my $var = $self->getObject("Variable",{
					entity_uuid => $term->variable_uuid(),
					type => $fluxtypes->[$k]
				});
				if (defined($var)) {
					$self->create("ObjectiveTerm",{
						coefficient => $term->coefficient(),
						variable_uuid => $var->uuid()
					});
				}
			}
		} elsif ($term->variableType() eq "biomassflux") {
			my $var = $self->getObject("Variable",{
				entity_uuid => $term->variable_uuid(),
				type => "biomassflux"
			});
			if (defined($var)) {
				$self->create("ObjectiveTerm",{
					coefficient => $term->coefficient(),
					variable_uuid => $var->uuid()
				});
			}
		}
	}
	$self->maximize($self->fbaFormulation()->maximizeObjective());
}

=head3 printLPfile
Definition:
	Output = ModelSEED::MS::Model->printLPfile({
		filename => string
	});
	Output = {
		success => 0/1
	};
Description:
	Prints FBA problem in LP formate
=cut
sub printLPfile {
	my ($self,$args) = @_;
	my $output = ["\\Problem name: LPProb",""];
	if ($self->maximize() == 1) {
		push(@{$output},"Maximize");	
	} else {
		push(@{$output},"Minimize");
	}
	my $currentString = " obj: ";
	my $count = 0;
	for (my $i=0; $i < @{$self->objectiveTerms()}; $i++) {
		my $sign = 1;
		my $obj = $self->objectiveTerms()->[$i];
		if ($count > 0) {
			if ($obj->coefficient() < 0) {
				$currentString .= " - ";
				$sign = -1;
			} else {
				$currentString .= " + ";
			}
		} elsif ($i > 0) {
			if ($obj->coefficient() < 0) {
				$currentString = "      - ";
				$sign = -1;
			} else {
				$currentString = "      + ";
			}
		}
		my $coef = $sign*$obj->coefficient();
		$currentString .= $coef." ".$obj->variable()->name();
		$count++;
		if ($count >= 4) {
			push(@{$output},$currentString);
			$count = 0;
			$currentString = "      + ";
		}
	}
	if ($count > 0) {
		push(@{$output},$currentString);	
	}
	push(@{$output},"Subject To");
	for (my $i=0; $i < @{$self->constraints()}; $i++) {
		my $const = $self->constraints()->[$i];
		my $ending;
		if ($const->equalityType() eq "=") {
			$ending = " = ".$const->rightHandSide();
		} elsif ($const->equalityType() eq ">") {
			$ending = " >= ".$const->rightHandSide();
		} elsif ($const->equalityType() eq "<") {
			$ending = " <= ".$const->rightHandSide();
		}
		$count = 0;
		$currentString = $const->name().": ";
		for (my $j=0; $j < @{$const->constraintVariables()}; $j++) {
			my $sign = 1;
			my $obj = $const->constraintVariables()->[$j];
			if ($count > 0) {
				if ($obj->coefficient() < 0) {
					$currentString .= " - ";
					$sign = -1;
				} else {
					$currentString .= " + ";
				}
			} elsif ($j > 0) {
				if ($obj->coefficient() < 0) {
					$currentString = "      - ";
					$sign = -1;
				} else {
					$currentString = "      + ";
				}
			}
			my $coef = $sign*$obj->coefficient();
			$currentString .= $coef." ".$obj->variable()->name();
			$count++;
			if ($count >= 4) {
				push(@{$output},$currentString);
				$count = 0;
			}
		}
		if ($count > 0) {
			$currentString .= $ending;
			push(@{$output},$currentString);
		} else {
			push(@{$output},"     ".$ending);
		}
	}
	push(@{$output},"Bounds");
	for (my $i=0; $i < @{$self->variables()}; $i++) {
		my $var = $self->variables()->[$i];
		if ($var->lowerBound() == $var->upperBound()) {
			push(@{$output},$var->name()." = ".$var->lowerBound());
		} else {
			push(@{$output},$var->lowerBound()." <= ".$var->name()." <= ".$var->upperBound());
		}
	}
	if ($self->milp() == 1) {
		push(@{$output},"Binaries");
		$currentString = "";
		$count = 0;
		for (my $i=0; $i < @{$self->variables()}; $i++) {
			if ($self->variables()->[$i]->binary() == 1) {
				$currentString .= "  ".$self->variables()->[$i]->name();
				$count++;
			}
			if ($count >= 4) {
				push(@{$output},$currentString);
				$count = 0;
				$currentString = "";
			}
		}
		if ($count > 0) {
			push(@{$output},$currentString);	
		}
	}
	push(@{$output},"End");
	ModelSEED::utilities::PRINTFILE($self->directory()."currentProb.lp",$output);
}

=head3 submitLPFile
Definition:
	Output = ModelSEED::MS::Model->submitLPFile({
		solver => string
		filename => 
	});
Description:
	Prints FBA problem in LP formate
=cut
sub submitLPFile {
	my ($self) = @_;
	my $command;
	my $solution = $self->create("Solution",{parent => $self});
	if ($self->solver() eq "cplex") {
		my $solver = "primopt";
		if ($self->milp() eq "1") {
			$solver = "mipopt";
		}
		ModelSEED::utilities::PRINTFILE($self->directory()."cplexcommands.txt",[
			"read",$self->directory()."currentProb.lp",$solver,"write",$self->directory()."solution.txt","sol","quit"
		]);
		system(ModelSEED::utilities::CPLEX()." < ".$self->directory()."cplexcommands.txt");
		$solution->buildFromCPLEXFile({filename => $self->directory()."solution.txt"});
	} elsif ($self->solver() eq "glpk") {
		system(ModelSEED::utilities::GLPK()." --cpxlp ".$self->directory()."currentProb.lp -o ".$self->directory()."solution.txt");
		$solution->buildFromGLPKFile({filename => $self->directory()."solution.txt"});
	}
	return $solution;
}

=head3 createFluxVariables
Definition:
	Output = ModelSEED::MS::Model->createFluxVariables();
	Output = {
		success => 0/1
	};
Description:
	Creates flux variables for all reactions in the input model
=cut
sub createFluxVariables {
	my ($self) = @_;
	#Creating flux variables
	for (my $i=0; $i < @{$self->model()->modelreactions()}; $i++) {
		my $rxn = $self->model()->modelreactions()->[$i];
		my $maxFlux = $self->fbaFormulation()->defaultMaxFlux();
		my $minFlux = -1*$maxFlux;
		for (my $j=0; $j < @{$self->fbaFormulation()->fbaReactionConstraints()}; $j++) {
			my $fbarxnconst = $self->fbaFormulation()->fbaReactionConstraints()->[$j];
			if ($fbarxnconst->reaction_uuid() eq $rxn->uuid() && $fbarxnconst->variableType() eq "flux") {
				$maxFlux = $fbarxnconst->max();
				$minFlux = $fbarxnconst->min();
			}
		}
		if ($self->model()->modelreactions()->[$i]->direction() eq ">") {
			$minFlux = 0;
		}
		if ($self->model()->modelreactions()->[$i]->direction() eq "<") {
			$maxFlux = 0;
		}
		if ($self->decomposeReversibleFlux() == 0) {
			$self->create("Variable",{
				name => "f_".$self->model()->modelreactions()->[$i]->id(),
				type => "flux",
				upperBound => $maxFlux,
				lowerBound => $minFlux,
				max => $maxFlux,
				min => $minFlux,
				entity_uuid => $self->model()->modelreactions()->[$i]->uuid()
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
			$self->create("Variable",{
				name => "ff_".$self->model()->modelreactions()->[$i]->id(),
				type => "forflux",
				upperBound => $posMax,
				lowerBound => $posMin,
				max => $posMax,
				min => $posMin,
				entity_uuid => $self->model()->modelreactions()->[$i]->uuid()
			});
			$self->create("Variable",{
				name => "rf_".$self->model()->modelreactions()->[$i]->id(),
				type => "revflux",
				upperBound => $negMax,
				lowerBound => $negMin,
				max => $negMax,
				min => $negMin,
				entity_uuid => $self->model()->modelreactions()->[$i]->uuid()
			});
		}
	}
	for (my $i=0; $i < @{$self->model()->biomasses()}; $i++) {
		my $bio = $self->model()->biomasses()->[$i];
		my $maxFlux = $self->fbaFormulation()->defaultMaxFlux();
		$self->create("Variable",{
			name => "f_biomass".$i,
			type => "biomassflux",
			upperBound => $maxFlux,
			lowerBound => 0,
			max => $maxFlux,
			min => 0,
			entity_uuid => $bio->uuid()
		});
	}
	#Setting variables
	for (my $i=0; $i < @{$self->variables()}; $i++) {
		$self->variables()->[$i]->index($i);
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
	my ($self) = @_;
	#Creating drain flux variables
	for (my $i=0; $i < @{$self->model()->modelcompounds()}; $i++) {
		my $cpd = $self->model()->modelcompounds()->[$i];
		if ($cpd->modelcompartment()->label() =~ m/^e/) {
			my $maxFlux = $self->fbaFormulation()->defaultMaxDrainFlux();
			my $minFlux = $self->fbaFormulation()->defaultMinDrainFlux();
			my $media = $self->fbaFormulation()->media();
			for (my $j=0; $j < @{$media->mediacompounds()}; $j++) {
				if ($media->mediacompounds()->[$j]->compound_uuid() eq $cpd->compound_uuid()) {
					$maxFlux = $media->mediacompounds()->[$j]->maxFlux();
					$minFlux = $media->mediacompounds()->[$j]->minFlux();
				}
			}
			for (my $j=0; $j < @{$self->fbaFormulation()->fbaCompoundConstraints()}; $j++) {
				my $fbacpdconst = $self->fbaFormulation()->fbaCompoundConstraints()->[$j];
				if ($fbacpdconst->modelcompound_uuid() eq $cpd->uuid() && $fbacpdconst->variableType() eq "drainflux") {
					$maxFlux = $fbacpdconst->max();
					$minFlux = $fbacpdconst->min();
				}
			}
			if ($self->decomposeReversibleDrainFlux() == 0) {
				$self->create("Variable",{
					name => "df_".$cpd->id(),
					type => "drainflux",
					upperBound => $maxFlux,
					lowerBound => $minFlux,
					max => $maxFlux,
					min => $minFlux,
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
				$self->create("Variable",{
					name => "fdf_".$cpd->id(),
					type => "fordrainflux",
					upperBound => $posMax,
					lowerBound => $posMin,
					max => $posMax,
					min => $posMin,
					entity_uuid => $cpd->uuid()
				});
				$self->create("Variable",{
					name => "rdf_".$cpd->id(),
					type => "revdrainflux",
					upperBound => $negMax,
					lowerBound => $negMin,
					max => $negMax,
					min => $negMin,
					entity_uuid => $cpd->uuid()
				});
			}
		} else {
			for (my $j=0; $j < @{$self->fbaFormulation()->fbaCompoundConstraints()}; $j++) {
				my $fbacpdconst = $self->fbaFormulation()->fbaCompoundConstraints()->[$j];
				if ($fbacpdconst->modelcompound_uuid() eq $cpd->uuid() && $fbacpdconst->variableType() eq "drainflux") {
					my $maxFlux = $fbacpdconst->max();
					my $minFlux = $fbacpdconst->min();
					if ($self->decomposeReversibleDrainFlux() == 0) {
						$self->create("Variable",{
							name => "df_".$cpd->id(),
							type => "drainflux",
							upperBound => $maxFlux,
							lowerBound => $minFlux,
							max => $maxFlux,
							min => $minFlux,
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
						$self->create("Variable",{
							name => "fdf_".$cpd->id(),
							type => "fordrainflux",
							upperBound => $posMax,
							lowerBound => $posMin,
							max => $posMax,
							min => $posMin,
							entity_uuid => $cpd->uuid()
						});
						$self->create("Variable",{
							name => "rdf_".$cpd->id(),
							type => "revdrainflux",
							upperBound => $negMax,
							lowerBound => $negMin,
							max => $negMax,
							min => $negMin,
							entity_uuid => $cpd->uuid()
						});
					}
				}
			}
		}
	}	
	#Setting variables
	for (my $i=0; $i < @{$self->variables()}; $i++) {
		$self->variables()->[$i]->index($i);
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
	my ($self) = @_;
	#Adding reaction stoichiometry
	for (my $i=0; $i < @{$self->model()->modelreactions()}; $i++) {
		my $rxn = $self->model()->modelreactions()->[$i];
		for (my $j=0; $j < @{$rxn->modelReactionReagents()}; $j++) {
			my $rgt = $rxn->modelReactionReagents()->[$j];
			my $const = $self->getObject("Constraint",{
				entity_uuid => $rgt->modelcompound_uuid(),
				type => "massbalance"
			});
			if (!defined($const)) {
				$const = $self->create("Constraint",{
					entity_uuid => $rgt->modelcompound_uuid(),
					name => "mb_".$rgt->modelcompound()->id(),
					type => "massbalance",
					rightHandSide => 0,
					equalityType => "=",
				});
			}
			my $fluxtypes = ["flux","forflux","revflux"];
			for (my $k=0; $k < @{$fluxtypes}; $k++) { 
				my $var = $self->getObject("Variable",{
					entity_uuid => $rxn->uuid(),
					type => $fluxtypes->[$k]
				});
				if (defined($var)) {
					$const->create("ConstraintVariable",{
						coefficient => $rgt->coefficient(),
						variable_uuid => $var->uuid()
					});
				}
			}
		}
	}
	#Adding biomass stoichiometry
	for (my $i=0; $i < @{$self->model()->biomasses()}; $i++) {
		for (my $j=0; $j < @{$self->model()->biomasses()->[$i]->biomasscompounds()}; $j++) {
			my $biocpd = $self->model()->biomasses()->[$i]->biomasscompounds()->[$j];
			my $const = $self->getObject("Constraint",{
				entity_uuid => $biocpd->modelcompound_uuid(),
				type => "massbalance"
			});
			if (!defined($const)) {
				$const = $self->create("Constraint",{
					entity_uuid => $biocpd->modelcompound_uuid(),
					name => "mb_".$biocpd->modelcompound()->id(),
					type => "massbalance",
					rightHandSide => 0,
					equalityType => "=",
				});
			}
			my $var = $self->getObject("Variable",{
				entity_uuid => $self->model()->biomasses()->[$i]->uuid(),
				type => "biomassflux"
			});
			if (defined($var)) {
				$const->create("ConstraintVariable",{
					coefficient => $biocpd->coefficient(),
					variable_uuid => $var->uuid()
				});
			} else {
				print "Variable ".$self->model()->biomasses()->[$i]->name()." not found!\n";	
			}
		}
	}
	#Adding drain fluxes
	for (my $i=0; $i < @{$self->variables()}; $i++) {
        if (   $self->variables()->[$i]->type() eq "drainflux"
            || $self->variables()->[$i]->type() eq "fordrainflux"
            || $self->variables()->[$i]->type() eq "revdrainflux")
        {
			my $coef = 1;
			if ($self->variables()->[$i]->type() eq "revdrainflux") {
				$coef = -1;
			}
			my $const = $self->getObject("Constraint",{
				entity_uuid => $self->variables()->[$i]->entity_uuid(),
				type => "massbalance"
			});
			if (!defined($const)) {
				my $numberOfConstraints = @{$self->constraints()};
				$const = $self->create("Constraint",{
					entity_uuid => $self->variables()->[$i]->entity_uuid(),
					name => "mb_".$numberOfConstraints,
					type => "massbalance",
					rightHandSide => 0,
					equalityType => "=",
				});
			}
			$const->create("ConstraintVariable",{
				coefficient => $coef,
				variable_uuid => $self->variables()->[$i]->uuid()
			});
		}
	}
	#Indexing constraints
	for (my $i=0; $i < @{$self->constraints()}; $i++) {
		$self->constraints()->[$i]->index($i);
	}
}

=head3 createFluxUseVariables
Definition:
	Output = ModelSEED::MS::Model->createFluxUseVariables();
	Output = {
		success => 0/1
	};
Description:
	Creates flux use variables for all fluxes in the input model
=cut
sub createFluxUseVariables {
	my ($self) = @_;
	my $newVariables;
	#First filtering out nonflux variables
	for (my $i=0; $i < @{$self->variables()}; $i++) {
		if ($self->variables()->[$i]->type() ne "fluxuse" && $self->variables()->[$i]->type() ne "forfluxuse" && $self->variables()->[$i]->type() ne "revfluxuse") {
			push(@{$newVariables},$self->variables()->[$i]);
		}
	}
	#Creating flux use variables
	for (my $i=0; $i < @{$self->variables()}; $i++) {
		if ($self->variables()->[$i]->type() eq "flux" || $self->variables()->[$i]->type() eq "forflux" || $self->variables()->[$i]->type() eq "revflux") {
			my $name = $self->variables()->[$i]->name();
			$name =~ s/^f_/fu_/;
			$name =~ s/^ff_/ffu_/;
			$name =~ s/^rf_/rfu_/;
			my $index = @{$newVariables};
			push(@{$newVariables},ModelSEED::MS::Variable->new({
				name => $name,
				type => $self->variables()->[$i]->type()."use",
				upperBound => 1,
				lowerBound => 0,
				max => 1,
				min => 0,
				"index" => $index,
				entity_uuid => $self->variables()->[$i]->entity_uuid()
			}));
		}
	}
	#Setting variables
	for (my $i=0; $i < @{$newVariables}; $i++) {
		$newVariables->[$i]->index($i);
	}
	$self->variables($newVariables);
}

=head3 createDrainFluxUseVariables
Definition:
	Output = ModelSEED::MS::Model->createDrainFluxUseVariables();
	Output = {
		success => 0/1
	};
Description:
	Creates drain flux use variables for all drain fluxes in the input model
=cut
sub createDrainFluxUseVariables {
	my ($self) = @_;
	my $newVariables;
	#First filtering out nonflux variables
	for (my $i=0; $i < @{$self->variables()}; $i++) {
		if ($self->variables()->[$i]->type() ne "drainfluxuse" && $self->variables()->[$i]->type() ne "fordrainfluxuse" && $self->variables()->[$i]->type() ne "revdrainfluxuse") {
			push(@{$newVariables},$self->variables()->[$i]);
		}
	}
	#Creating flux use variables
	for (my $i=0; $i < @{$self->variables()}; $i++) {
		if ($self->variables()->[$i]->type() eq "drainflux" || $self->variables()->[$i]->type() eq "fordrainflux" || $self->variables()->[$i]->type() eq "revdrainflux") {
			my $name = $self->variables()->[$i]->name();
			$name =~ s/^df_/dfu_/;
			$name =~ s/^fdf_/fdfu_/;
			$name =~ s/^rdf_/rdfu_/;
			push(@{$newVariables},ModelSEED::MS::Variable->new({
				name => $name,
				type => $self->variables()->[$i]->type()."use",
				upperBound => 1,
				lowerBound => 0,
				max => 1,
				min => 0,
				entity_uuid => $self->variables()->[$i]->entity_uuid()
			}));
		}
	}
	#Setting variables
	for (my $i=0; $i < @{$newVariables}; $i++) {
		$newVariables->[$i]->index($i);
	}
	$self->variables($newVariables);
}

=head3 createUseVariableConstraints
Definition:
	Output = ModelSEED::MS::Model->createUseVariableConstraints();
	Output = {
		success => 0/1
	};
Description:
	Creates use variable constraints
=cut
sub createUseVariableConstraints {
	my ($self) = @_;
	my $newConstraints;
	for (my $i=0; $i < @{$self->constraints()}; $i++) {
		if ($self->constraints()->[$i]->type() !~ m/use$/) {
			push(@{$newConstraints},$self->constraints()->[$i]);
		}
	}
	for (my $i=0; $i < @{$self->variables()}; $i++) {
		if ($self->variables()->[$i]->type() =~ m/use$/) {
			my $const = ModelSEED::MS::Constraint->new({
				entity_uuid => $self->variables()->[$i]->entity_uuid(),
				name => $self->variables()->[$i]->name(),
				type => "useconstraint",
				rightHandSide => 0,
				equalityType => "<",
			});
			my $type = $self->variables()->[$i]->type();
			$type =~ s/use$//;
			push(@{$newConstraints},$const);
			my $fluxVar = $self->getObject("Variable",{
				entity_uuid => $self->variables()->[$i]->entity_uuid(),
				type => $type,
			});
			$const->create("ConstraintVariable",{
				coefficient => 1,
				variable_uuid => $fluxVar->uuid()
			});
			$const->create("ConstraintVariable",{
				coefficient => -1*$fluxVar->upperBound(),
				variable_uuid => $self->variables()->[$i]->uuid()
			});
		}
	}
	#Setting constraints
	for (my $i=0; $i < @{$newConstraints}; $i++) {
		$newConstraints->[$i]->index($i);
	}
	$self->constraints($newConstraints);
}

__PACKAGE__->meta->make_immutable;
1;
