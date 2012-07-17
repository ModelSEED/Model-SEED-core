########################################################################
# ModelSEED::MS::FBAResult - This is the moose object corresponding to the FBAResult object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-05-25T05:08:47
########################################################################
use strict;
use ModelSEED::MS::DB::FBAResult;
package ModelSEED::MS::FBAResult;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::FBAResult';
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
=head3 buildFromOptSolution
Definition:
	ModelSEED::MS::FBAResults = ModelSEED::MS::FBAResults->runFBA();
Description:
	Runs the FBA study described by the fomulation and returns a typed object with the results
=cut
sub buildFromOptSolution {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["LinOptSolution"],{});
	my $solvars = $args->{LinOptSolution}->solutionvariables();
	for (my $i=0; $i < @{$solvars}; $i++) {
		my $var = $solvars->[$i];
		my $type = $var->variable()->type();
		if ($type eq "flux" || $type eq "forflux" || $type eq "revflux" || $type eq "fluxuse" || $type eq "forfluxuse" || $type eq "revfluxuse") {
			$self->integrateReactionFluxRawData($var);
		} elsif ($type eq "biomassflux") {
			$self->add("fbaBiomassVariables",{
				biomass_uuid => $var->variable()->entity_uuid(),
				variableType => $type,
				lowerBound => $var->variable()->lowerBound(),
				upperBound => $var->variable()->upperBound(),
				min => $var->min(),
				max => $var->max(),
				value => $var->value()
			});
		} elsif ($type eq "drainflux" || $type eq "fordrainflux" || $type eq "revdrainflux" || $type eq "drainfluxuse" || $type eq "fordrainfluxuse" || $type eq "revdrainfluxuse") {
			$self->integrateCompoundFluxRawData($var);
		}
	}	
}
=head3 integrateReactionFluxRawData
Definition:
	void ModelSEED::MS::FBAResults->integrateReactionFluxRawData();
Description:
	Translates a raw flux or flux use variable into a reaction variable with decomposed reversible reactions recombined
=cut
sub integrateReactionFluxRawData {
	my ($self,$solVar) = @_;
	my $type = "flux";
	my $max = 0;
	my $min = 0;
	my $var = $solVar->variable();
	if ($var->type() =~ m/use$/) {
		$max = 1;
		$min = -1;
		$type = "fluxuse";	
	}
	my $fbavar = $self->queryObject("fbaReactionVariables",{
		modelreaction_uuid => $var->entity_uuid(),
		variableType => $type
	});
	if (!defined($fbavar)) {
		$fbavar = $self->add("fbaReactionVariables",{
			modelreaction_uuid => $var->entity_uuid(),
			variableType => $type,
			lowerBound => $min,
			upperBound => $max,
			min => $min,
			max => $max,
			value => 0
		});
	}
	if ($var->type() eq $type) {
		$fbavar->upperBound($var->upperBound());
		$fbavar->lowerBound($var->lowerBound());
		$fbavar->max($solVar->max());
		$fbavar->min($solVar->min());
		$fbavar->value($solVar->value());
	} elsif ($var->type() eq "for".$type) {
		if ($var->upperBound() > 0) {
			$fbavar->upperBound($var->upperBound());	
		}
		if ($var->lowerBound() > 0) {
			$fbavar->lowerBound($var->lowerBound());
		}
		if ($solVar->max() > 0) {
			$fbavar->max($solVar->max());
		}
		if ($solVar->min() > 0) {
			$fbavar->min($solVar->min());
		}
		if ($solVar->value() > 0) {
			$fbavar->value($fbavar->value() + $solVar->value());
		}
	} elsif ($var->type() eq "rev".$type) {
		if ($var->upperBound() > 0) {
			$fbavar->lowerBound((-1*$var->upperBound()));
		}
		if ($var->lowerBound() > 0) {
			$fbavar->upperBound((-1*$var->lowerBound()));
		}
		if ($solVar->max() > 0) {
			$fbavar->min((-1*$solVar->max()));
		}
		if ($solVar->min() > 0) {
			$fbavar->max((-1*$solVar->min()));
		}
		if ($solVar->value() > 0) {
			$fbavar->value($fbavar->value() - $solVar->value());
		}
	}
}
=head3 integrateCompoundFluxRawData
Definition:
	void ModelSEED::MS::FBAResults->integrateCompoundFluxRawData();
Description:
	Translates a raw flux or flux use variable into a compound variable with decomposed reversible reactions recombined
=cut
sub integrateCompoundFluxRawData {
	my ($self,$solVar) = @_;
	my $var = $solVar->variable();
	my $type = "drainflux";
	my $max = 0;
	my $min = 0;
	if ($var->type() =~ m/use$/) {
		$max = 1;
		$min = -1;
		$type = "drainfluxuse";	
	}
	my $fbavar = $self->queryObject("fbaCompoundVariables",{
		modelcompound_uuid => $var->entity_uuid(),
		variableType => $type
	});
	if (!defined($fbavar)) {
		$fbavar = $self->add("fbaCompoundVariables",{
			modelcompound_uuid => $var->entity_uuid(),
			variableType => $type,
			lowerBound => $min,
			upperBound => $max,
			min => $min,
			max => $max,
			value => 0
		});
	}
	if ($var->type() eq $type) {
		$fbavar->upperBound($var->upperBound());
		$fbavar->lowerBound($var->lowerBound());
		$fbavar->max($solVar->max());
		$fbavar->min($solVar->min());
		$fbavar->value($solVar->value());
	} elsif ($var->type() eq "for".$type) {
		if ($var->upperBound() > 0) {
			$fbavar->upperBound($var->upperBound());	
		}
		if ($var->lowerBound() > 0) {
			$fbavar->lowerBound($var->lowerBound());
		}
		if ($solVar->max() > 0) {
			$fbavar->max($solVar->max());
		}
		if ($solVar->min() > 0) {
			$fbavar->min($solVar->min());
		}
		if ($solVar->value() > 0) {
			$fbavar->value($fbavar->value() + $solVar->value());
		}
	} elsif ($var->type() eq "rev".$type) {
		if ($var->upperBound() > 0) {
			$fbavar->lowerBound((-1*$var->upperBound()));
		}
		if ($var->lowerBound() > 0) {
			$fbavar->upperBound((-1*$var->lowerBound()));
		}
		if ($solVar->max() > 0) {
			$fbavar->min((-1*$solVar->max()));	
		}
		if ($solVar->min() > 0) {
			$fbavar->max((-1*$solVar->min()));
		}
		if ($solVar->value() > 0) {
			$fbavar->value($fbavar->value() - $solVar->value());
		}
	}
}
=head3 loadMFAToolkitResults
Definition:
	void ModelSEED::MS::FBAResult->loadMFAToolkitResults();
Description:
	Loads problem result data from job directory
=cut
sub loadMFAToolkitResults {
	my ($self) = @_;
	$self->parseProblemReport();
	$self->parseFluxFiles();
	$self->parseMetaboliteProduction();
	$self->parseFBAPhenotypeOutput();#not checked
	$self->parseMinimalMediaResults();
	$self->parseCombinatorialDeletionResults();
	$self->parseFVAResults();
}
=head3 parseFluxFiles
Definition:
	void ModelSEED::MS::Model->parseFluxFiles();
Description:
	Parses files with flux data
=cut
sub parseFluxFiles {
	my ($self) = @_;
	my $directory = $self->parent()->jobDirectory();
	if (-e $directory."/MFAOutput/SolutionCompoundData.txt") {
		my $tbl = ModelSEED::utilities::LOADTABLE($directory."/MFAOutput/SolutionCompoundData.txt",";");
		my $drainCompartmentColumns = {};
		my $compoundColumn = -1;
		for (my $i=0; $i < @{$tbl->{headings}}; $i++) {
			if ($tbl->{headings}->[$i] eq "Compound") {
				$compoundColumn = $i;
			} elsif ($tbl->{headings}->[$i] =~ m/Drain\[([a-zA-Z0-9]+)\]/) {
				$drainCompartmentColumns->{$1} = $i;
			}
		}
		if ($compoundColumn != -1) {
			foreach my $row (@{$tbl->{data}}) {
				foreach my $comp (keys(%{$drainCompartmentColumns})) {
					if ($row->[$drainCompartmentColumns->{$comp}] ne "none") {
						my $mdlcpd = $self->model()->queryObject("modelcompounds",{id => $row->[$compoundColumn]."_".$comp."0"});
						if (defined($mdlcpd)) {
							$self->add("fbaCompoundVariables",{
								modelcompound_uuid => $mdlcpd->uuid(),
								variableType => "drainflux",
								value => $row->[$drainCompartmentColumns->{$comp}]
							});
						}
					}
				}
			}
		}
	}
	if (-e $directory."/MFAOutput/SolutionReactionData.txt") {
		my $tbl = ModelSEED::utilities::LOADTABLE($directory."/MFAOutput/SolutionReactionData.txt",";");
		my $fluxCompartmentColumns = {};
		my $reactionColumn = -1;
		for (my $i=0; $i < @{$tbl->{headings}}; $i++) {
			if ($tbl->{headings}->[$i] eq "Reaction") {
				$reactionColumn = $i;
			} elsif ($tbl->{headings}->[$i] =~ m/Flux\[([a-zA-Z0-9]+)\]/) {
				$fluxCompartmentColumns->{$1} = $i;
			}
		}
		if ($reactionColumn != -1) {
			foreach my $row (@{$tbl->{data}}) {
				foreach my $comp (keys(%{$fluxCompartmentColumns})) {
					if ($row->[$fluxCompartmentColumns->{$comp}] ne "none") {
						my $mdlrxn = $self->model()->queryObject("modelreactions",{id => $row->[$reactionColumn]."_".$comp."0"});
						if (defined($mdlrxn)) {
							$self->add("fbaReactionVariables",{
								modelreaction_uuid => $mdlrxn->uuid(),
								variableType => "flux",
								value => $row->[$fluxCompartmentColumns->{$comp}]
							});
						}
					}
				}
			}
		}
	}
}
=head3 parseFBAPhenotypeOutput
Definition:
	void ModelSEED::MS::Model->parseFBAPhenotypeOutput();
Description:
	Parses output file generated by FBAPhenotypeSimulation
=cut
sub parseFBAPhenotypeOutput {
	my ($self) = @_;
	my $directory = $self->parent()->jobDirectory();
	if (-e $directory."/FBAExperimentOutput.txt") {
		#Loading file results into a hash
		my $tbl = ModelSEED::utilities::LOADTABLE($directory."/FBAExperimentOutput.txt",";");
		if (!defined($tbl->{data}->[0]->[5])) {
			return ModelSEED::utilities::ERROR("output file did not contain necessary data");
		}
		my $phenoOutputHash;
		foreach my $row (@{$tbl->{data}}) {
			if (defined($row->[5])) {
				my $fraction = 0;
				if ($row->[5] < 1e-7) {
					$row->[5] = 0;	
				}
				if ($row->[4] < 1e-7) {
					$row->[4] = 0;	
				} else {
					$fraction = $row->[5]/$row->[4];	
				}
				$phenoOutputHash->{$row->[0]} = {
					simulatedGrowth => $row->[5],
					wildtype => $row->[4],
					simulatedGrowthFraction => $fraction,
					noGrowthCompounds => [],
					dependantReactions => [],
					dependantGenes => [],
					fluxes => {},
					class => "UN"
				};
				if (defined($row->[6]) && length($row->[6]) > 0) {
					chomp($row->[6]);
					$phenoOutputHash->{$row->[0]}->{noGrowthCompounds} = [split(/;/,$row->[6])];
				}
				if (defined($row->[7]) && length($row->[7]) > 0) {
					$phenoOutputHash->{$row->[0]}->{dependantReactions} = [split(/;/,$row->[7])];
				}
				if (defined($row->[8]) && length($row->[8]) > 0) {
					$phenoOutputHash->{$row->[0]}->{dependantReactions} = [split(/;/,$row->[8])];
				}
				if (defined($row->[9]) && length($row->[9]) > 0) {
					my @fluxList = split(/;/,$row->[9]);
					for (my $j=0; $j < @fluxList; $j++) {
						my @temp = split(/:/,$fluxList[$j]);
						$phenoOutputHash->{$row->[0]}->{fluxes}->{$temp[0]} = $temp[1];
					}
				}
			}
		}
		#Scanning through all phenotype data in FBAFormulation and creating corresponding phenotype result objects
		my $phenos = $self->parent()->fbaPhenotypeSimulations();
		for (my $i=0; $i < @{$phenos}; $i++) {
			my $pheno = $phenos->[$i];
			if (defined($phenoOutputHash->{$pheno->uuid()})) {
				if (defined($pheno->observedGrowthFraction())) {
					if ($pheno->observedGrowthFraction() > 0.0001) {
						if ($phenoOutputHash->{$pheno->uuid()}->{simulatedGrowthFraction} > 0) {
							$phenoOutputHash->{$pheno->uuid()}->{class} = "CP";
						} else {
							$phenoOutputHash->{$pheno->uuid()}->{class} = "FN";
						}
					} else {
						if ($phenoOutputHash->{$pheno->uuid()}->{simulatedGrowthFraction} > 0) {
							$phenoOutputHash->{$pheno->uuid()}->{class} = "FP";
						} else {
							$phenoOutputHash->{$pheno->uuid()}->{class} = "CN";
						}
					}
				}
				$self->add("fbaPhenotypeSimultationResults",$phenoOutputHash->{$pheno->uuid()});	
			}
		}
		return 1;
	}
	return 0;
}
=head3 parseMetaboliteProduction
Definition:
	void ModelSEED::MS::Model->parseMetaboliteProduction();
Description:
	Parses metabolite production file
=cut
sub parseMetaboliteProduction {
	my ($self) = @_;
	my $directory = $self->parent()->jobDirectory();
	if (-e $directory."/MFAOutput/MetaboliteProduction.txt") {
		my $tbl = ModelSEED::utilities::LOADTABLE($directory."/MFAOutput/MetaboliteProduction.txt",";");
		foreach my $row (@{$tbl->{data}}) {
			if (defined($row->[1])) {
				my $cpd = $self->model()->queryObject("modelcompounds",{id => $row->[0]."_c0"});
				if (defined($cpd)) {
					$self->add("fbaMetaboliteProductionResults",{
						modelCompound_uuid => $cpd->uuid(),
						maximumProduction => -1*$row->[1]
					});
				}
			}
		}
		return 1;
	}
	return 0;
}
=head3 parseProblemReport
Definition:
	void ModelSEED::MS::Model->parseProblemReport();
Description:
	Parses problem report
=cut
sub parseProblemReport {
	my ($self) = @_;
	my $directory = $self->parent()->jobDirectory();
	if (-e $directory."/ProblemReport.txt") {
		my $tbl = ModelSEED::utilities::LOADTABLE($directory."/ProblemReport.txt",";");
		my $column;
		for (my $i=0; $i < @{$tbl->{headings}}; $i++) {
			if ($tbl->{headings}->[$i] eq "Objective") {
				$column = $i;
				last;
			}
		}
		if (defined($tbl->{data}->[0]) && defined($tbl->{data}->[0]->[$column])) {
			$self->objectiveValue($tbl->{data}->[0]->[$column]);
		}
		return 1;
	}
	return 0;
}
=head3 parseMinimalMediaResults
Definition:
	void ModelSEED::MS::Model->parseMinimalMediaResults();
Description:
	Parses minimal media result file
=cut
sub parseMinimalMediaResults {
	my ($self) = @_;
	my $directory = $self->parent()->jobDirectory();
	if (-e $directory."/MFAOutput/MinimalMediaResults.txt") {
		my $data = ModelSEED::utilities::LOADFILE($directory."/MFAOutput/MinimalMediaResults.txt");
		my $essIDs = [split(/;/,$data->[1])];
		my $essCpds;
		my $essuuids;
		for (my $i=0; $i < @{$essIDs};$i++) {
			my $cpd = $self->biochemistry()->queryObject("compounds",{id => $essIDs->[$i]});
			if (defined($cpd)) {
				push(@{$essCpds},$cpd);
				push(@{$essuuids},$cpd->uuid());	
			}
		}
		my $count = 1;
		for (my $i=3; $i < @{$data}; $i++) {
			if ($data->[$i] !~ m/^Dead/) {
				my $optIDs = [split(/;/,$data->[$i])];
				my $optCpds;
				my $optuuids;
				for (my $j=0; $j < @{$optIDs};$j++) {
					my $cpd = $self->biochemistry()->queryObject("compounds",{id => $optIDs->[$j]});
					if (defined($cpd)) {
						push(@{$optCpds},$cpd);
						push(@{$optuuids},$cpd->uuid());
					}
				}
				my $minmedia = $self->biochemistry()->add("media",{
					isDefined => 1,
					isMinimal => 1,
					id => "MinimalMedia-".$self->uuid()."-".$count,
					name => "MinimalMedia-".$self->uuid()."-".$count,
					type => "PredictedMinimal"
				});
				for (my $j=0; $j < @{$essCpds};$j++) {
					$minmedia->add("mediacompounds",{
						compound_uuid => $essCpds->[$j]->uuid(),
						concentration => 0.001,
						maxFlux => 100,
						minFlux => -100
					});
				}
				for (my $j=0; $j < @{$optCpds};$j++) {
					$minmedia->add("mediacompounds",{
						compound_uuid => $optCpds->[$j]->uuid(),
						concentration => 0.001,
						maxFlux => 100,
						minFlux => -100
					});
				}	
				$self->add("minimalMediaResults",{
					minimalMedia_uuid => $minmedia->uuid(),
					essentialNutrient_uuids => $essuuids,
					optionalNutrient_uuids => $optuuids
				});
				$count++;
			} else {
				last;	
			}
		}
	}
}
=head3 parseCombinatorialDeletionResults
Definition:
	void ModelSEED::MS::Model->parseCombinatorialDeletionResults();
Description:
	Parses combinatorial deletion results
=cut
sub parseCombinatorialDeletionResults {
	my ($self) = @_;
	my $directory = $self->parent()->jobDirectory();
	if (-e $directory."/MFAOutput/CombinationKO.txt") {
		my $tbl = ModelSEED::utilities::LOADTABLE($directory."/MFAOutput/CombinationKO.txt","\t");
		my $genomeid = $self->annotation()->genomes()->[0]->id();
		foreach my $row (@{$tbl->{data}}) {
			if (defined($row->[1])) {
				my $array = [split(/;/,$row->[0])];
				my $geneArray = [];
				for (my $i=0; $i < @{$array}; $i++) {
					my $geneID = $array->[$i];
					if ($geneID =~ m/^peg\.\d+/) {
						$geneID = "fig|".$genomeid.".".$geneID;
					}
					my $gene = $self->annotation()->queryObject("features",{id => $geneID});
					if (defined($gene)) {
						push(@{$geneArray},$gene->uuid());	
					}
				}
				if (@{$geneArray} > 0) {
					$self->add("fbaDeletionResults",{
						geneko_uuids => $geneArray,
						growthFraction => $row->[1]
					});
				}
			}
		}
		return 1;
	}
	return 0;
}
=head3 parseFVAResults
Definition:
	void ModelSEED::MS::Model->parseFVAResults();
Description:
	Parses FVA results
=cut
sub parseFVAResults {
	my ($self) = @_;
	my $directory = $self->parent()->jobDirectory();
	if (-e $directory."/MFAOutput/TightBoundsReactionData.txt" && -e $directory."/MFAOutput/TightBoundsCompoundData.txt") {
		my $tbl = ModelSEED::utilities::LOADTABLE($directory."/MFAOutput/TightBoundsReactionData.txt",";",1);
		if (defined($tbl->{headings}) && defined($tbl->{data})) {
			my $idColumn = -1;
			my $vartrans = {
				FLUX => ["flux",-1,-1],
				DELTAGG_ENERGY => ["deltag",-1,-1],
				REACTION_DELTAG_ERROR => ["deltagerr",-1,-1]
			};
			my $deadRxn = {};
			if (-e $directory."/DeadReactions.txt") {
				my $inputArray = ModelSEED::utilities::LOADFILE($directory."/DeadReactions.txt","");
				if (defined($inputArray)) {
					for (my $i=0; $i < @{$inputArray}; $i++) {
						$deadRxn->{$inputArray->[$i]} = 1;
					}
				}
			}
			for (my $i=0; $i < @{$tbl->{headings}}; $i++) {
				if ($tbl->{headings}->[$i] eq "DATABASE ID") {
					$idColumn = $i;
				} else {
					foreach my $vartype (keys(%{$vartrans})) {
						if ($tbl->{headings}->[$i] eq "Max ".$vartype) {
							$vartrans->{$vartype}->[2] = $i;
							last;
						} elsif ($tbl->{headings}->[$i] eq "Min ".$vartype) {
							$vartrans->{$vartype}->[1] = $i;
							last;
						}
					}
				}
			}
			if ($idColumn >= 0) {
				for (my $i=0; $i < @{$tbl->{data}}; $i++) {
					my $row = $tbl->{data}->[$i];
					if (defined($row->[$idColumn])) {
						my $comp = "c";
						my $id = $row->[$idColumn]."_".$comp."0";	
						my $mdlrxn = $self->model()->queryObject("modelreactions",{id => $id});
						if (defined($mdlrxn)) {
							foreach my $vartype (keys(%{$vartrans})) {
								if ($vartrans->{$vartype}->[1] != -1 && $vartrans->{$vartype}->[2] != -1) {
									my $min = $row->[$vartrans->{$vartype}->[1]];
									my $max = $row->[$vartrans->{$vartype}->[2]];
									if (abs($min) < 0.0000001) {
										$min = 0;	
									}
									if (abs($max) < 0.0000001) {
										$max = 0;	
									}
									my $fbaRxnVar = $self->queryObject("fbaReactionVariables",{
										modelreaction_uuid => $mdlrxn->uuid(),
										variableType => $vartrans->{$vartype}->[0],
									});
									if (!defined($fbaRxnVar)) {
										$fbaRxnVar = $self->add("fbaReactionVariables",{
											modelreaction_uuid => $mdlrxn->uuid(),
											variableType => $vartrans->{$vartype}->[0]
										});	
									}
									$fbaRxnVar->min($min);
									$fbaRxnVar->max($max);
									if (defined($deadRxn->{$id})) {
										$fbaRxnVar->class("Dead");
									} elsif ($fbaRxnVar->min() > 0) {
										$fbaRxnVar->class("Positive");
									} elsif ($fbaRxnVar->max() < 0) {
										$fbaRxnVar->class("Negative");
									} elsif ($fbaRxnVar->min() == 0 && $fbaRxnVar->max() > 0) {
										$fbaRxnVar->class("Positive variable");
									} elsif ($fbaRxnVar->max() == 0 && $fbaRxnVar->min() < 0) {
										$fbaRxnVar->class("Negative variable");
									} elsif ($fbaRxnVar->max() == 0 && $fbaRxnVar->min() == 0) {
										$fbaRxnVar->class("Blocked");
									} else {
										$fbaRxnVar->class("Variable");
									}
								}
							}
						}
					}
				}
			}
		}
		$tbl = ModelSEED::utilities::LOADTABLE($directory."/MFAOutput/TightBoundsCompoundData.txt",";",1);
		if (defined($tbl->{headings}) && defined($tbl->{data})) {
			my $idColumn = -1;
			my $compColumn = -1;
			my $vartrans = {
				DRAIN_FLUX => ["drainflux",-1,-1],
				LOG_CONC => ["conc",-1,-1],
				DELTAGF_ERROR => ["deltagferr",-1,-1],
				POTENTIAL => ["potential",-1,-1]
			};
			my $deadCpd = {};
			my $deadendCpd = {};
			if (-e $directory."/DeadMetabolites.txt") {
				my $inputArray = ModelSEED::utilities::LOADFILE($directory."/DeadMetabolites.txt","");
				if (defined($inputArray)) {
					for (my $i=0; $i < @{$inputArray}; $i++) {
						$deadCpd->{$inputArray->[$i]} = 1;
					}
				}
			}
			if (-e $directory."/DeadEndMetabolites.txt") {
				my $inputArray = ModelSEED::utilities::LOADFILE($directory."/DeadEndMetabolites.txt","");
				if (defined($inputArray)) {
					for (my $i=0; $i < @{$inputArray}; $i++) {
						$deadendCpd->{$inputArray->[$i]} = 1;
					}
				}
			}
			for (my $i=0; $i < @{$tbl->{headings}}; $i++) {
				if ($tbl->{headings}->[$i] eq "DATABASE ID") {
					$idColumn = $i;
				} elsif ($tbl->{headings}->[$i] eq "COMPARTMENT") {
					$compColumn = $i;
				} else {
					foreach my $vartype (keys(%{$vartrans})) {
						if ($tbl->{headings}->[$i] eq "Max ".$vartype) {
							$vartrans->{$vartype}->[2] = $i;
						} elsif ($tbl->{headings}->[$i] eq "Min ".$vartype) {
							$vartrans->{$vartype}->[1] = $i;
						}
					}
				}
			}
			if ($idColumn >= 0) {
				for (my $i=0; $i < @{$tbl->{data}}; $i++) {
					my $row = $tbl->{data}->[$i];
					if (defined($row->[$idColumn])) {
						my $comp = $row->[$compColumn];
						my $id = $row->[$idColumn]."_".$comp."0";	
						my $mdlcpd = $self->model()->queryObject("modelcompounds",{id => $id});
						if (defined($mdlcpd)) {
							foreach my $vartype (keys(%{$vartrans})) {
								if ($vartrans->{$vartype}->[1] != -1 && $vartrans->{$vartype}->[2] != -1) {
									my $min = $row->[$vartrans->{$vartype}->[1]];
									my $max = $row->[$vartrans->{$vartype}->[2]];
									if ($min != 10000000) {
										if (abs($min) < 0.0000001) {
											$min = 0;	
										}
										if (abs($max) < 0.0000001) {
											$max = 0;	
										}
										my $fbaCpdVar = $self->queryObject("fbaCompoundVariables",{
											modelcompound_uuid => $mdlcpd->uuid(),
											variableType => $vartrans->{$vartype}->[0],
										});
										if (!defined($fbaCpdVar)) {
											$fbaCpdVar = $self->add("fbaCompoundVariables",{
												modelcompound_uuid => $mdlcpd->uuid(),
												variableType => $vartrans->{$vartype}->[0],
											});	
										}
										$fbaCpdVar->min($min);
										$fbaCpdVar->max($max);
										if (defined($deadCpd->{$id})) {
											$fbaCpdVar->class("Dead");
										} elsif (defined($deadendCpd->{$id})) {
											$fbaCpdVar->class("Deadend");
										} elsif ($fbaCpdVar->min() > 0) {
											$fbaCpdVar->class("Positive");
										} elsif ($fbaCpdVar->max() < 0) {
											$fbaCpdVar->class("Negative");
										} elsif ($fbaCpdVar->min() == 0 && $fbaCpdVar->max() > 0) {
											$fbaCpdVar->class("Positive variable");
										} elsif ($fbaCpdVar->max() == 0 && $fbaCpdVar->min() < 0) {
											$fbaCpdVar->class("Negative variable");
										} elsif ($fbaCpdVar->max() == 0 && $fbaCpdVar->min() == 0) {
											$fbaCpdVar->class("Blocked");
										} else {
											$fbaCpdVar->class("Variable");
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
}

__PACKAGE__->meta->make_immutable;
1;
