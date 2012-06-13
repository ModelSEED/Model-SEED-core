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
	if (!defined($rxn->reactioninstance()->reaction()->deltaG()) || $rxn->reactioninstance()->reaction()->deltaG() eq 10000000) {
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
		if ($set->containsReaction($rxn->reactioninstance()) == 1) {
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
	return $self->emergencyGapfilling({
		model => $model,
		media => $self->media()
	});
#	my $fbaform = $args->{fbaFormulation};
#	#Creating default FBAFormulation if one was not provided
#	if (!defined($fbaform)) {
#		my $maxDrain = 0;
#		if ($self->media()->name() eq "Complete") {
#			$maxDrain = 10000;
#		}
#		$fbaform = ModelSEED::MS::FBAFormulation->new({
#			name => "Gapfilling growth test",
#			model_uuid => $model->uuid(),
#			model => $model,
#			media_uuid => $self->media_uuid(),
#			media => $self->media(),
#			type => "singlegrowth",
#			biochemistry_uuid => $self->biochemistry_uuid(),
#			biochemistry => $self->biochemistry(),
#			description => "Gapfilling growth test",
#			growthConstraint => "none",
#			thermodynamicConstraints => "none",
#			allReversible => 0,
#			defaultMaxFlux => 1000,
#			defaultMaxDrainFlux => $maxDrain,
#			defaultMinDrainFlux => -10000,
#			decomposeReversibleFlux => 0,
#			decomposeReversibleDrainFlux => 0,
#			fluxUseVariables => 0,
#			drainfluxUseVariables => 0,
#			maximizeObjective => 1,
#			fbaObjectiveTerms => [{
#				coefficient => 1,
#				entityType => "Biomass",
#				variableType => "biomassflux",
#				entity_uuid => $model->biomasses()->[0]->uuid()
#			}]			
#		});
#	}
#	#Testing if the object function is already greater than zero
#	print "Testing for zero objective!\n";
#	my $fbasolution = $fbaform->runFBA();
#	if ($fbasolution->objectiveValue() > 0.0000001) {
#		print "Objective is already greater than zero. No gapfilling needed!\n";
#		return undef;
#	}
#	print "Objective is zero. Proceeding with gapfilling!\n";
#	#Creating the database model
#	my $dbmodel = $self->biochemistry()->makeDBModel({
#		balancedOnly => $self->balancedReactionsOnly(),
#		allowableCompartments => $self->allowableCompartments(),
#		guaranteedReactions => $self->guaranteedReactions(),
#		forbiddenReactions => $self->blacklistedReactions()
#	});
#	#Merging in the model selected for gapfilling
#	$dbmodel->mergeModel({
#		model => $model
#	});
#	#Creating gapfilling FBAFormulation
#	my $gffbaform = ModelSEED::MS::FBAFormulation->new({
#		name => "Gapfilling simulation",
#		model_uuid => $dbmodel->uuid(),
#		model => $dbmodel,
#		media_uuid => $self->media_uuid(),
#		media => $self->media(),
#		type => "gapfilling",
#		biochemistry_uuid => $self->biochemistry_uuid(),
#		biochemistry => $self->biochemistry(),
#		description => "Gapfilling simulation",
#		growthConstraint => "none",
#		thermodynamicConstraints => "none",
#		allReversible => 1,
#		defaultMaxFlux => 1000,
#		defaultMaxDrainFlux => $fbaform->defaultMaxDrainFlux(),
#		defaultMinDrainFlux => -10000,
#		decomposeReversibleFlux => 1,
#		decomposeReversibleDrainFlux => 0,
#		fluxUseVariables => 1,
#		drainfluxUseVariables => 0,
#		maximizeObjective => 0,			
#	});
#	my $typesToAttribute = {
#		ModelReaction => "modelreactions",
#		ModelCompound => "modelcompounds",
#		Biomass => "biomasses"
#	};
#	#Copying all constraints from previous FBAFormulation
#	for (my $i=0; $i < @{$fbaform->fbaConstraints()}; $i++) {
#		my $oldConst = $fbaform->fbaConstraints()->[$i];
#		my $const = $gffbaform->add("fbaConstraints",{
#			name => $oldConst->name(),
#			rhs => $oldConst->rhs(),
#			sign => $oldConst->sign()
#		});
#		for (my $j=0; $j < @{$oldConst->fbaConstraintVariables()}; $j++) {
#			my $term = $fbaform->fbaObjectiveTerms()->[$j];
#			my $obj = $dbmodel->queryObject($typesToAttribute->{$term->entityType()},{mapped_uuid => $term->entity_uuid()});
#			$const->add("fbaConstraintVariables",{
#				entity_uuid => $obj->entity_uuid(),
#				entityType => $term->entityType(),
#				variableType => $term->variableType(),
#				coefficient => $term->coefficient()
#			});
#		}
#	}
#	#Making a constraint forcing the previous objective to be greater than zero
#	my $const = $gffbaform->add("fbaConstraints",{
#		name => "ObjectiveConstraint",
#		rhs => 0.01,
#		sign => ">"
#	});
#	for (my $i=0; $i < @{$fbaform->fbaObjectiveTerms()}; $i++) {
#		my $term = $fbaform->fbaObjectiveTerms()->[$i];
#		my $obj = $dbmodel->queryObject($typesToAttribute->{$term->entityType()},{mapped_uuid => $term->entity_uuid()});
#		$const->add("fbaConstraintVariables",{
#			entity_uuid => $obj->uuid(),
#			entityType => $term->entityType(),
#			variableType => $term->variableType(),
#			coefficient => $term->coefficient()
#		});
#	}
#	#Labeling all dbmodel reactions as candidates and creating objective terms
#	my $mdlrxns = $dbmodel->modelreactions();
#	for (my $i=0; $i < @{$mdlrxns}; $i++) {
#		my $rxn = $mdlrxns->[$i];
#		if (!defined($rxn->modelReactionProteins()->[0])) {
#			print "Adding candidate protein!\n";
#			$rxn->add("modelReactionProteins",{
#				complex_uuid => "00000000-0000-0000-0000-000000000000",
#				note => "CANDIDATE"
#			});
#		}
#		my $costs = $self->calculateReactionCosts({modelreaction => $rxn});
#		if ($costs->{forwardDirection} != 0) {
#			$gffbaform->add("fbaObjectiveTerms",{
#				entity_uuid => $rxn->uuid(),
#				entityType => "ModelReaction",
#				variableType => "forfluxuse",
#				coefficient => $costs->{forwardDirection}
#			});
#		}
#		if ($costs->{reverseDirection} != 0) {
#			$gffbaform->add("fbaObjectiveTerms",{
#				entity_uuid => $rxn->uuid(),
#				entityType => "ModelReaction",
#				variableType => "revfluxuse",
#				coefficient => $costs->{reverseDirection}
#			});
#		}
#	}
#	#Running the flux balance analysis for the gapfilling optimization problem
#	my $solution = $gffbaform->runFBA();
#	my $readable = $solution->createReadableStringArray();
#	my $directory = "C:/Code/Model-SEED-core/data/exampleObjects/";
#	ModelSEED::utilities::PRINTFILE($directory."GapfillSolution.readable",$readable);
#	#Translating te solution into a gapfilling solution
#	my $gfsolution = $self->add("gapfillingSolutions",{
#		solutionCost => $solution->objectiveValue()
#	});
#	my $rxnvars = $solution->fbaReactionVariables();
#	for (my $i=0; $i < @{$rxnvars}; $i++) {
#		my $var = $rxnvars->[$i];
#		if ($var->variableType() eq "flux") {
#			my $rxn = $var->modelreaction();
#			if ($var->value() < -0.0000001) {
#				if (defined($rxn->modelReactionProteins()->[0]) && $rxn->modelReactionProteins()->[0]->note() eq "CANDIDATE") {
#					print "New reaction <=!";
#					my $direction = "<";
#					if ($rxn->direction() ne $direction) {
#						$direction = "=";
#					}
#					$gfsolution->add("gapfillingSolutionReactions",{
#						reactioninstance_uuid => $rxn->reactioninstance_uuid(),
#						reactioninstance => $rxn->reactioninstance(),
#						direction => $direction
#					});
#				} elsif ($rxn->direction() eq ">") {
#					print "Direction change!";
#					$gfsolution->add("gapfillingSolutionReactions",{
#						reactioninstance_uuid => $rxn->reactioninstance_uuid(),
#						reactioninstance => $rxn->reactioninstance(),
#						direction => "="
#					});
#				}
#			} elsif ($var->value() > 0.0000001) {
#				if (defined($rxn->modelReactionProteins()->[0]) && $rxn->modelReactionProteins()->[0]->note() eq "CANDIDATE") {
#					print "New reaction =>!";
#					my $direction = ">";
#					if ($rxn->direction() ne $direction) {
#						$direction = "=";
#					}
#					$gfsolution->add("gapfillingSolutionReactions",{
#						reactioninstance_uuid => $rxn->reactioninstance_uuid(),
#						reactioninstance => $rxn->reactioninstance(),
#						direction => $direction
#					});
#				} elsif ($rxn->direction() eq "<") {
#					print "Direction change!";
#					$gfsolution->add("gapfillingSolutionReactions",{
#						reactioninstance_uuid => $rxn->reactioninstance_uuid(),
#						reactioninstance => $rxn->reactioninstance(),
#						direction => "="
#					});
#				}
#			}
#		}
#	}
#	return $gfsolution;
}
=head3 emergencyGapfilling
Definition:
	ModelSEED::MS::GapfillingSolution = ModelSEED::MS::GapfillingFormulation->emergencyGapfilling({
		model => ModelSEED::MS::Model(REQ)
	});
Description:
	Identifies the solution that gapfills the input model - written quickly to use MFAToolkit when performance issues were discovered in FBAProblem
=cut
sub emergencyGapfilling {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["model","media"],{});
	my $model = $args->{model};
	my $media = $args->{media};
	#Creating job directory and copying in the default gapfilling job data
	my $dataDir = "/vol/model-dev/MODEL_DEV_DB/";
	#my $dataDir = ModelSEED::utilities::MODELSEEDCORE()."data/";
	my $dir = File::Temp::tempdir(DIR => $dataDir."ReactionDB/MFAToolkitOutputFiles")."/";
	File::Path::mkpath ($dir."reaction");
	my $directory = substr($dir,62);
	#chop($directory);
	print $directory;
	#Print model to Model.tbl
	my $mdlData = ["REACTIONS","LOAD;DIRECTIONALITY;COMPARTMENT;ASSOCIATED PEG"];
	my $mdlrxn = $model->modelreactions();
	for (my $i=0; $i < @{$mdlrxn}; $i++) {
		my $rxn = $mdlrxn->[$i];
		my $line = $rxn->reactioninstance()->id().";".$rxn->direction().";c;";
		$line .= $rxn->gprString();
		$line =~ s/fig\|\d+\.\d+\.//g;
		push(@{$mdlData},$line);
	}
	push(@{$mdlData},"bio00001;=>;c;UNIVERSAL");
	ModelSEED::utilities::PRINTFILE($dir."Model.tbl",$mdlData);
	#Print biomass reaction to:
	my $equation = $model->biomasses()->[0]->equation();
	$equation =~ s/\+/ + /g;
	$equation =~ s/\)cpd/) cpd/g;
	$equation =~ s/=\>/ => /g;
	my $bioData = ["NAME\tBiomass","DATABASE\tbio00001","EQUATION\t".$equation];
	ModelSEED::utilities::PRINTFILE($dir."reaction/bio00001",$bioData);
	ModelSEED::utilities::PRINTFILE($dir."InactiveModelReactions.txt",["bio00001"]);
	#Set CompleteGapfillingParameters.txt
	my $defaultMax = 0;
	if ($media->name() eq "Complete") {
		$defaultMax = 10000;
	}
	my $gauranteedRxn = join(",",@{$self->guaranteedReactions()});
	my $blacklistedRxn = join(";",@{$self->blacklistedReactions()});
	$gauranteedRxn =~ s/Reaction\/ModelSEED\///g;
	$blacklistedRxn =~ s/Reaction\/ModelSEED\///g;
	my $name = $media->name();
	my $params = [
		"Default max drain flux|".$defaultMax."|MFA parameters",
		"Reaction activation bonus|0|MFA parameters",
		"MFASolver|CPLEX|MFA parameters",
		"create file on completion|GapfillingComplete.txt|MFA parameters",
		"Allowable unbalanced reactions|".$gauranteedRxn."|MFA parameters",
		"output folder|2678472/|MFA parameters",
		"just print LP file|0|MFA parameters",
		"Default min drain flux|-10000|MFA parameters",
		"Objective coefficient file|NONE|MFA parameters",
		"Minimum flux for use variable positive constraint|0.01|MFA parameters",
		"exchange species|cpd11416[c]:-10000:0|MFA parameters",
		"Reactions to knockout|".$blacklistedRxn."|MFA parameters",
		"Complete gap filling|1|MFA parameters",
		"user bounds filename|Complete|MFA parameters",
		"dissapproved compartments|p;n;m;x;g;r;v|MFA parameters",
		"output folder|".$directory."|MFA parameters",
		"user bounds filename|".$name."|MFA parameters",
		"database spec file|".$dir."StringDBFile.txt|MFA parameters",
		"use database fields|1|MFA parameters"
	];
	ModelSEED::utilities::PRINTFILE($dir."CompleteGapfillingParameters.txt",$params);
	#Write media formulation
	my $variables = "";
	my $maxes = "";
	my $mins = "";
	my $types = "";
	my $comps = "";
	my $mediaCpds = $media->mediacompounds();
	for (my $i=0; $i < @{$mediaCpds}; $i++) {
		$maxes .= $mediaCpds->[$i]->maxFlux()."|";
		$mins .= "-100|";
		$types .= "DRAIN_FLUX|";
		$comps .= "e|";
		$variables .= $mediaCpds->[$i]->compound()->id()."|";
	}
	chop($variables);
	chop($maxes);
	chop($mins);
	chop($types);
	chop($comps);
	my $mediaData = [
		"ID\tNAMES\tVARIABLES\tTYPES\tMAX\tMIN\tCOMPARTMENTS",
		$name."\t".$name."\t".$variables."\t".$types."\t".$maxes."\t".$mins."\t".$comps
	];
	ModelSEED::utilities::PRINTFILE($dir."media.tbl",$mediaData);
	#Set StringDBFile.txt
	my $stringdb = [
		"Name\tID attribute\tType\tPath\tFilename\tDelimiter\tItem delimiter\tIndexed columns",
		"compound\tid\tSINGLEFILE\t".$dataDir."ReactionDB/compounds/\t".$dataDir."fbafiles/compoundDataFile.tbl\tTAB\tSC\tid",
		"reaction\tid\tSINGLEFILE\t".$dir."reaction/\t".$dataDir."fbafiles/reactionDataFile.tbl\tTAB\t|\tid",
		"cue\tNAME\tSINGLEFILE\t\t".$dataDir."ReactionDB/MFAToolkitInputFiles/cueTable.txt\tTAB\t|\tNAME",
		"media\tID\tSINGLEFILE\t".$dataDir."ReactionDB/Media/\t".$dir."media.tbl\tTAB\t|\tID;NAMES"		
	];
	ModelSEED::utilities::PRINTFILE($dir."StringDBFile.txt",$stringdb);
	#Write shell script
	my $exec = [
		"source ".ModelSEED::utilities::MODELSEEDCORE()."bin/source-me.sh",
		ModelSEED::utilities::MODELSEEDCORE().'software/mfatoolkit/bin/mfatoolkit resetparameter "MFA input directory" '.$dataDir.'ReactionDB/ parameterfile "../Parameters/ProductionMFA.txt" parameterfile "../Parameters/GapFilling.txt" parameterfile "'.$dir.'CompleteGapfillingParameters.txt" LoadCentralSystem "'.$dir.'Model.tbl" > "'.$dir.'log.txt"'
	];
	ModelSEED::utilities::PRINTFILE($dir."runMFAToolkit.sh",$exec);
	chmod 0775,$dir."runMFAToolkit.sh";
	#Run shell script
	system($dir."runMFAToolkit.sh");
	#Parse CompleteGapfillingOutput.txt
	if (!-e $dir."CompleteGapfillingOutput.txt") {
		print "Gapfilling failed!";
		return undef;
	}
	my $filedata = ModelSEED::utilities::LOADFILE($dir."CompleteGapfillingOutput.txt");
	my $gfsolution = $self->add("gapfillingSolutions",{});
	my $count = 0;
	for (my $i=0; $i < @{$filedata}; $i++) {
		if ($filedata->[$i] =~ m/^bio00001/) {
			my $array = [split(/\t/,$filedata->[$i])];
			if (defined($array->[1])) {
				my $subarray = [split(/;/,$array->[1])];
				for (my $j=0; $j < @{$subarray}; $j++) {
					if ($subarray->[$j] =~ m/([\-\+])(rxn\d\d\d\d\d)/) {
						my $rxnid = $2;
						my $sign = $1;
						my $rxn = $model->biochemistry()->queryObject("reactioninstances",{id => $rxnid});
						if (!defined($rxn)) {
							ModelSEED::utilities::ERROR("Could not find gapfilled reaction ".$rxnid."!");
						}
						my $mdlrxn = $model->queryObject("modelreactions",{reactioninstance_uuid => $rxn->uuid()});
						my $direction = "=>";
						if ($sign eq "-") {
							$direction = "<=";
						}
						if ($rxn->direction() ne $direction) {
							$direction = "<=>";
						}
						if (defined($mdlrxn)) { 
							$mdlrxn->direction("<=>");
						} else {
							$model->addReactionInstanceToModel({
								reactionInstance => $rxn,
								direction => $direction
							});
						}
						$count++;
						$gfsolution->add("gapfillingSolutionReactions",{
							reactioninstance_uuid => $rxn->uuid(),
							reactioninstance => $rxn,
							direction => $direction
						});
						
					}
				}
			}
			
		}
	}
	$gfsolution->solutionCost($count);
	return $gfsolution;
}

__PACKAGE__->meta->make_immutable;
1;
