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
	$self->parseFBAPhenotypeOutput();
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
						my $mdlcpd = $self->model()->queryObject("modelcompounds",{id => $row->[$compoundColumn]."[".$comp."]"});
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
	if (-e $self->directory()."/MFAOutput/SolutionReactionData.txt") {
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
						my $mdlrxn = $self->model()->queryObject("modelreactions",{id => $row->[$reactionColumn]."[".$comp."]"});
						if (defined($mdlrxn)) {
							$self->add("fbaReactionVariables",{
								modelreaction_uuid => $mdlrxn->uuid(),
								variableType => "drainflux",
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
				my $cpd = $self->model()->queryObject("modelcompounds",{id => $row->[0]."[c]"});
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
		#TODO
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
		my $result;
		push(@{$result->{essentialNutrients}},split(/;/,$data->[1]));
		my $mediaCpdList = [@{$result->{essentialNutrients}}];
		for (my $i=3; $i < @{$data}; $i++) {
			if ($data->[$i] !~ m/^Dead/) {
				my $temp;
				push(@{$temp},split(/;/,$data->[$i]));
				push(@{$mediaCpdList},@{$temp});
				push(@{$result->{optionalNutrientSets}},$temp);
			} else {
				last;
			}	
		}	
		for (my $i=0; $i < @{$mediaCpdList}; $i++) {
			my $mediacpd = $self->figmodel()->database()->create_moose_object("mediacpd",{
				MEDIA => $self->model()."-minimal",
				entity => $mediaCpdList->[$i],
				type => "COMPOUND",
				concentration => 0.001,
				maxFlux => 10000,
				minFlux => -10000
			});
			push(@{$media->mediaCompounds()},$mediacpd);
		}
		$result->{minimalMedia} = $media;
		return $result;
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
		my $tbl = ModelSEED::utilities::LOADTABLE($directory."/MFAOutput/CombinationKO.txt",";");
		foreach my $row (@{$tbl->{data}}) {
			if (defined($row->[1])) {
				my $array = [split(/;/,$row->[0])];
				my $geneArray;
				for (my $i=0; $i < @{$array}; $i++) {
					my $gene = $self->annotation()->queryObject("features",{id => $array->[$i]});
					if (defined($gene)) {
						push(@{$geneArray},$gene->uuid());	
					}
				}
				if (@{$geneArray} > 0) {
					$self->add("fbaMetaboliteProductionResults",{
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
	if (!-e $self->directory()."/MFAOutput/TightBoundsReactionData.txt") {
		return {error => $self->error_message({function => "parseTightBounds",message=>"could not find tight bound results file",args=>$args})};
	}
	my $results = {inactive=>"",dead=>"",positive=>"",negative=>"",variable=>"",posvar=>"",negvar=>"",positiveBounds=>"",negativeBounds=>"",variableBounds=>"",posvarBounds=>"",negvarBounds=>""};
	my $table = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->directory()."/MFAOutput/TightBoundsReactionData.txt",";","|",1,["DATABASE ID"]);
	my $variableTypes = ["FLUX","DELTAGG_ENERGY","REACTION_DELTAG_ERROR"];
	my $varAssoc = {
		FLUX => "",
		DELTAGG_ENERGY => " DELTAG",
		REACTION_DELTAG_ERROR => " SDELTAG",
		DRAIN_FLUX => "",
		DELTAGF_ERROR => " SDELTAGF",
		POTENTIAL => " POTENTIAL",
		LOG_CONC => " CONC"
	};
	for (my $i=0; $i < $table->size(); $i++) {
		my $row = $table->get_row($i);
		for (my $j=0; $j < @{$variableTypes}; $j++) {
			if (defined($row->{"Max ".$variableTypes->[$j]})) {
				$results->{tb}->{$row->{"DATABASE ID"}->[0]}->{"max".$varAssoc->{$variableTypes->[$j]}} = $row->{"Max ".$variableTypes->[$j]}->[0];
				$results->{tb}->{$row->{"DATABASE ID"}->[0]}->{"min".$varAssoc->{$variableTypes->[$j]}} = $row->{"Min ".$variableTypes->[$j]}->[0];
				if (abs($results->{tb}->{$row->{"DATABASE ID"}->[0]}->{"max".$varAssoc->{$variableTypes->[$j]}}) < 0.0000001) {
					$results->{tb}->{$row->{"DATABASE ID"}->[0]}->{"max".$varAssoc->{$variableTypes->[$j]}} = 0;
				}
				if (abs($results->{tb}->{$row->{"DATABASE ID"}->[0]}->{"min".$varAssoc->{$variableTypes->[$j]}}) < 0.0000001) {
					$results->{tb}->{$row->{"DATABASE ID"}->[0]}->{"min".$varAssoc->{$variableTypes->[$j]}} = 0;
				}
			}
		}
	}
	#Loading compound tight bounds
	if (!-e $self->directory()."/MFAOutput/TightBoundsCompoundData.txt") {
		return {error => $self->error_message({function => "parseTightBounds",message=>"could not find tight bound results file",args=>$args})};
	}
	$table = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->directory()."/MFAOutput/TightBoundsCompoundData.txt",";","|",1,["DATABASE ID"]);
	$variableTypes = ["DRAIN_FLUX","LOG_CONC","DELTAGF_ERROR","POTENTIAL"];
	for (my $i=0; $i < $table->size(); $i++) {
		my $row = $table->get_row($i);
		for (my $j=0; $j < @{$variableTypes}; $j++) {
			if (defined($row->{"Max ".$variableTypes->[$j]}) && $row->{"Max ".$variableTypes->[$j]}->[0] ne "1e+007") {
				$results->{tb}->{$row->{"DATABASE ID"}->[0].$row->{COMPARTMENT}->[0]}->{"max".$varAssoc->{$variableTypes->[$j]}} = $row->{"Max ".$variableTypes->[$j]}->[0];
				$results->{tb}->{$row->{"DATABASE ID"}->[0].$row->{COMPARTMENT}->[0]}->{"min".$varAssoc->{$variableTypes->[$j]}} = $row->{"Min ".$variableTypes->[$j]}->[0];
				if (abs($results->{tb}->{$row->{"DATABASE ID"}->[0].$row->{COMPARTMENT}->[0]}->{"max".$varAssoc->{$variableTypes->[$j]}}) < 0.0000001) {
					$results->{tb}->{$row->{"DATABASE ID"}->[0].$row->{COMPARTMENT}->[0]}->{"max".$varAssoc->{$variableTypes->[$j]}} = 0;
				}
				if (abs($results->{tb}->{$row->{"DATABASE ID"}->[0].$row->{COMPARTMENT}->[0]}->{"min".$varAssoc->{$variableTypes->[$j]}}) < 0.0000001) {
					$results->{tb}->{$row->{"DATABASE ID"}->[0].$row->{COMPARTMENT}->[0]}->{"min".$varAssoc->{$variableTypes->[$j]}} = 0;
				}
			}
		}
	}
	#Setting class of modeled objects
	foreach my $obj (keys(%{$results->{tb}})) {
		$results->{tb}->{$obj}->{class} = "Variable";
		if ($results->{tb}->{$obj}->{min} > 0.000001) {
			$results->{tb}->{$obj}->{class} = "Positive";
			if ($obj =~ m/rxn/ || $obj =~ m/bio/) {
				$results->{positive} .= $obj.";";
				$results->{positiveBounds} .= $results->{tb}->{$obj}->{min}.":".$results->{tb}->{$obj}->{max}.";";
			}
		} elsif ($results->{tb}->{$obj}->{max} < -0.000001) {
			$results->{tb}->{$obj}->{class} = "Negative";
			if ($obj =~ m/rxn/ || $obj =~ m/bio/) {
				$results->{negative} .= $obj.";";
				$results->{negativeBounds} .= $results->{tb}->{$obj}->{min}.":".$results->{tb}->{$obj}->{max}.";";
			}
		} elsif ($results->{tb}->{$obj}->{max} < 0.0000001) {
			if ($results->{tb}->{$obj}->{min} > -0.0000001) {
				$results->{tb}->{$obj}->{class} = "Blocked";
			} else {
				$results->{tb}->{$obj}->{class} = "Negative variable";
				if ($obj =~ m/rxn/ || $obj =~ m/bio/) {
					$results->{negvar} .= $obj.";";
					$results->{negvarBounds} .= $results->{tb}->{$obj}->{min}.";";
				}
			}
		} elsif ($results->{tb}->{$obj}->{min} > -0.0000001) {
			$results->{tb}->{$obj}->{class} = "Positive variable";
			if ($obj =~ m/rxn/ || $obj =~ m/bio/) {
				$results->{posvar} .= $obj.";";
				$results->{posvarBounds} .= $results->{tb}->{$obj}->{max}.";";
			}
		} elsif ($obj =~ m/rxn/ || $obj =~ m/bio/) {
			$results->{variable} .= $obj.";";
			$results->{variableBounds} .= $results->{tb}->{$obj}->{min}.":".$results->{tb}->{$obj}->{max}.";";
		}
	}
	#Loading dead reactions from network analysis
	if (-e $self->directory()."/DeadReactions.txt") {
		my $inputArray = $self->figmodel()->database()->load_single_column_file($self->directory()."/DeadReactions.txt","");
		if (defined($inputArray)) {
			for (my $i=0; $i < @{$inputArray}; $i++) {
				if (defined($results->{tb}->{$inputArray->[$i]}) && $results->{tb}->{$inputArray->[$i]}->{class} eq "Blocked") {
					$results->{tb}->{$inputArray->[$i]}->{class} = "Dead";
					$results->{dead} .= $inputArray->[$i].";";
				}			
			}
		}
	}
	foreach my $obj (keys(%{$results->{tb}})) {
		if ($results->{tb}->{$obj}->{class} eq "Blocked" && ($obj =~ m/rxn/ || $obj =~ m/bio/)) {
			$results->{inactive} .= $obj.";";
		}
	}
	#Loading dead compounds from network analysis
	if (-e $self->directory()."/DeadMetabolites.txt") {
		my $inputArray = $self->figmodel()->database()->load_single_column_file($self->directory()."/DeadMetabolites.txt","");
		if (defined($inputArray)) {
			for (my $i=0; $i < @{$inputArray}; $i++) {
				if (defined($results->{tb}->{$inputArray->[$i]})) {
					$results->{tb}->{$inputArray->[$i]."c"}->{class} = "Dead";
				}			
			}
		}
	}
	if (-e $self->directory()."/DeadEndMetabolites.txt") {
		my $inputArray = $self->figmodel()->database()->load_single_column_file($self->directory()."/DeadEndMetabolites.txt","");
		if (defined($inputArray)) {
			for (my $i=0; $i < @{$inputArray}; $i++) {
				if (defined($results->{tb}->{$inputArray->[$i]})) {
					$results->{tb}->{$inputArray->[$i]."c"}->{class} = "Deadend";
				}			
			}
		}
	}
}


__PACKAGE__->meta->make_immutable;
1;
