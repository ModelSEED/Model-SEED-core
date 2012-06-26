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
has jobID => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildjobid' );
has jobPath => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildjobpath' );
has jobDirectory => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildjobdirectory' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildjobid {
	my ($self) = @_;
	my $path = $self->jobPath();
	my $fulldir = File::Temp::tempdir(DIR => $path);
	if (!-d $fulldir) {
		File::Path::mkpath ($fulldir);
	}
	my $jobid = substr($fulldir,length($path."/"));
	return $jobid
}

sub _buildjobpath {
	my ($self) = @_;
	my $path = ModelSEED::utilities::MODELSEEDCORE()."data/fbajobs";
	if (!-d $path) {
		File::Path::mkpath ($path);
	}
	return $path;
}

sub _buildjobdirectory {
	my ($self) = @_;
	return $self->jobPath()."/".$self->jobID();
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
	if (!-e $self->jobDirectory()."runMFAToolkit.sh") {
		$self->createJobDirectory();
	}
	system($self->jobDirectory()."runMFAToolkit.sh");
	my $fbaresults = $self->add("fbaResults",{});
	$fbaresults->loadMFAToolkitResults();
	return $fbaresults;
}
=head3 createJobDirectory
Definition:
	void ModelSEED::MS::Model->createJobDirectory();
Description:
	Creates the MFAtoolkit job directory
=cut
sub createJobDirectory {
	my ($self) = @_;
	my $directory = $self->jobDirectory();
	my $translation = {
		drainflux => "DRAIN_FLUX",
		flux => "FLUX"
	};
	#Print model to Model.tbl
	my $model = $self->parent();
	my $mdlData = ["REACTIONS","LOAD;DIRECTIONALITY;COMPARTMENT;ASSOCIATED PEG"];
	my $mdlrxn = $model->modelreactions();
	for (my $i=0; $i < @{$mdlrxn}; $i++) {
		my $rxn = $mdlrxn->[$i];
		my $line = $rxn->reaction()->id().";".$rxn->direction().";c;";
		$line .= $rxn->gprString();
		$line =~ s/kb\|g\.\d+\.//g;
		$line =~ s/fig\|\d+\.\d+\.//g;
		push(@{$mdlData},$line);
	}
	my $biomasses = $model->biomasses();
	for (my $i=0; $i < @{$biomasses}; $i++) {
		my $bio = $biomasses->[$i];
		push(@{$mdlData},$bio->id().";=>;c;UNIVERSAL");
		my $equation = $bio->equation();
		$equation =~ s/\+/ + /g;
		$equation =~ s/\)cpd/) cpd/g;
		$equation =~ s/=\>/ => /g;
		my $bioData = ["NAME\tBiomass","DATABASE\t".$bio->id(),"EQUATION\t".$equation];
		ModelSEED::utilities::PRINTFILE($directory."reaction/".$bio->id(),$bioData);
	}
	ModelSEED::utilities::PRINTFILE($directory."Model.tbl",$mdlData);
	#Setting drain max based on media
	my $media = $self->media();
	my $defaultMax = 0;
	if ($media->name() eq "Complete") {
		$defaultMax = 10000;
	}
	#Selecting the solver based on whether the problem is MILP
	my $solver = "GLPK";
	if ($self->fluxUseVariables() == 1 || $self->drainfluxUseVariables() == 1 || $self->findMinimalMedia()) {
		$solver = "CPLEX"
	}
	#Setting gene KO
	my $geneKO = "none";
	for (my $i=0; $i < @{$self->geneKO()}; $i++) {
		my $gene = $self->geneKO()->[$i];
		if ($i == 0) {
			$geneKO = $gene->id();	
		} else {
			$geneKO .= ";".$gene->id();
		}
	}
	#Setting reaction KO
	my $rxnKO = "none";
	for (my $i=0; $i < @{$self->reactionKO()}; $i++) {
		my $rxn = $self->reactionKO()->[$i];
		if ($i == 0) {
			$rxnKO = $rxn->id();	
		} else {
			$rxnKO .= ";".$rxn->id();
		}
	}
	#Setting exchange species
	my $exchange = "cpd11416[c]:-10000:0";
	#TODO
	#Setting the objective
	my $objective = "MAX";
	my $metToOpt = "none";
	my $optMetabolite = 1;
	if ($self->fva() == 1 || $self->comboDeletions() > 0) {
		$optMetabolite = 0;
	}
	if ($self->maximizeObjective() == 0) {
		$objective = "MIN";
		$optMetabolite = 0;
	}
	my $objterms = $self->fbaObjectiveTerms();
	for (my $i=0; $i < @{$objterms}; $i++) {
		my $objterm = $objterms->[$i];
		my $objVarName = "";
		my $objVarComp = "none";
		if (lc($objterm->entityType()) eq "compound") {
			my $entity = $model->getObject("modelcompounds",$objterm->entity_uuid());
			if (defined($entity)) {
				$objVarName = $entity->compound()->id();
				$objVarComp = $entity->modelcompartment()->label();
			}
			$optMetabolite = 0;
		} elsif (lc($objterm->entityType()) eq "reaction") {
			my $entity = $model->getObject("modelreactions",$objterm->entity_uuid());
			if (defined($entity)) {
				$objVarName = $entity->reaction()->id();
				$objVarComp = $entity->modelcompartment()->label();
			}
			$metToOpt = "REACTANTS;".$entity->reaction()->id();
		} elsif (lc($objterm->entityType()) eq "biomass") {
			my $entity = $model->getObject("modelreactions",$objterm->entity_uuid());
			if (defined($entity)) {
				$objVarName = $entity->id();
				$objVarComp = "none";
			}
			$metToOpt = "REACTANTS;".$entity->id();
		}
		if (length($objVarName) > 0) {
			$objective .= ";".$translation->{$objterm->variableType()}.";".$objVarName.";".$objVarComp.";".$objterm->coefficient();
		}
	}
	if (@{$objterms} > 1) {
		$optMetabolite = 0;	
	}
	#Setting up uptake limits
	my $uptakeLimits = "none";
	foreach my $atom (keys(%{$self->uptakeLimits()})) {
		if ($uptakeLimits eq "none") {
			$uptakeLimits = $atom.":".$self->uptakeLimits()->{$atom};
		} else {
			$uptakeLimits .= ";".$atom.":".$self->uptakeLimits()->{$atom};
		}
	}
	my $comboDeletions = $self->comboDeletions();
	if ($comboDeletions == 0) {
		$comboDeletions = "none";
	}
	#Creating FBA experiment file
	my $fbaExpFile = "none";
	my $fbaSims = $self->fbaPhenotypeSimulations();
	if (@{$fbaSims} > 0) {
		$fbaExpFile = "FBAExperiment.txt";
		my $phenoData = ["Label\tKO\tMedia"];
		for (my $i=0; $i < @{$fbaSims}; $i++) {
			my $phenoko = "none";
			for (my $j=0; $j < @{$fbaSims->[$i]->geneKO()}; $j++) {
				if ($phenoko eq "none") {
					$phenoko = $fbaSims->[$i]->geneKO()->[$j]->id();
				} else {
					$phenoko .= ";".$fbaSims->[$i]->geneKO()->[$j]->id();
				}
			}
			for (my $j=0; $j < @{$fbaSims->[$i]->reactionKO()}; $j++) {
				if ($phenoko eq "none") {
					$phenoko = $fbaSims->[$i]->reactionKO()->[$j]->id();
				} else {
					$phenoko .= ";".$fbaSims->[$i]->reactionKO()->[$j]->id();
				}
			}
			push(@{$phenoData},$fbaSims->[$i]->label()."\t".$phenoko."\t".$fbaSims->[$i]->media()->name());
		}
		ModelSEED::utilities::PRINTFILE($directory.$fbaExpFile,$phenoData);
	}
	#Setting parameters
	my $parameters = {
		"Default min drain flux" => $self->defaultMinDrainFlux(),
		"Default max drain flux" => $self->defaultMaxDrainFlux(),
		"Max flux" => $self->defaultMaxFlux(),
		"Min flux" => -1*$self->defaultMaxFlux(),
		"user bounds filename" => $self->media()->name(),
		"create file on completion" => "FBAComplete.txt",
		"Reactions to knockout" => $rxnKO,
		"Genes to knockout" => $geneKO,
		"output folder" => $self->jobid()."/",
		"use database fields" => 1,
		"MFASolver" => $solver,
		"exchange species" => $exchange,
		"database spec file" => $directory."StringDBFile.txt",
		"Reactions use variables" => $self->fluxUseVariables(),
		"Force use variables for all reactions" => 1,
		"Add use variables for any drain fluxes" => $self->drainfluxUseVariables(),
		"Decompose reversible reactions" => $self->decomposeReversibleFlux(),
		"Decompose reversible drain fluxes" => $self->decomposeReversibleDrainFlux(),
		"Make all reactions reversible in MFA" => $self->allReversible(),
		"Constrain objective to this fraction of the optimal value" => $self->objectiveConstraintFraction(),
		"objective" => $objective,
		"find tight bounds" => $self->fva(),
		"Combinatorial deletions" => $comboDeletions,
		"flux minimization" => $self->fluxMinimization(), 
		"uptake limits" => $uptakeLimits,
		"optimize metabolite production if objective is zero" => $optMetabolite,
		"metabolites to optimize" => $metToOpt,
		"FBA experiment file" => $fbaExpFile,
		"determine minimal required media" => $self->findMinimalMedia(),
		"Recursive MILP solution limit" => $self->numberOfSolutions()
	};
	#Setting thermodynamic constraints
	if ($self->thermodynamicConstraints() eq "none") {
		$parameters->{"Thermodynamic constraints"} = 0;
	} elsif ($self->thermodynamicConstraints() eq "simple") {
		$parameters->{"Thermodynamic constraints"} = 1;
		$parameters->{"simple thermo constraints"} = 1;
	} elsif ($self->thermodynamicConstraints() eq "error") {
		$parameters->{"Thermodynamic constraints"} = 1;
		$parameters->{"Account for error in delta G"} = 1;
		$parameters->{"minimize deltaG error"} = 0;
	} elsif ($self->thermodynamicConstraints() eq "noerror") {
		$parameters->{"Thermodynamic constraints"} = 1;
		$parameters->{"Account for error in delta G"} = 0;
		$parameters->{"minimize deltaG error"} = 0;
	} elsif ($self->thermodynamicConstraints() eq "minerror") {
		$parameters->{"Thermodynamic constraints"} = 1;
		$parameters->{"Account for error in delta G"} = 1;
		$parameters->{"minimize deltaG error"} = 1;
	}
	#Setting overide parameters
	foreach my $param (keys(%{$self->parameters()})) {
		$parameters->{$param} = $self->parameters()->{$param};
	}
	#Printing parameter file
	my $paramData = [];
	foreach my $param (keys(%{$parameters})) {
		push(@{$paramData},$param."|".$parameters->{$param}."|Specialized parameters");
	}
	ModelSEED::utilities::PRINTFILE($directory."SpecializedParameters.txt",$paramData);
	#Printing specialized bounds
	my $userBounds = {};
	my $mediaCpds = $media->mediacompounds();
	for (my $i=0; $i < @{$mediaCpds}; $i++) {
		$userBounds->{$mediaCpds->[$i]->compound()->id()}->{"e"}->{"DRAIN_FLUX"} = {
			max => $mediaCpds->[$i]->maxFlux(),
			min => $mediaCpds->[$i]->minFlux()
		};
	}
	
	my $cpdbnds = $self->fbaCompoundBounds();
	for (my $i=0; $i < @{$cpdbnds}; $i++) {
		$userBounds->{$cpdbnds->[$i]->compound()->id()}->{$cpdbnds->[$i]->modelcompartment()->label()}->{$translation->{$cpdbnds->[$i]->variableType()}} = {
			max => $cpdbnds->[$i]->upperBound(),
			min => $cpdbnds->[$i]->lowerBound()
		};
	}
	my $rxnbnds = $self->fbaReactionBounds();
	for (my $i=0; $i < @{$rxnbnds}; $i++) {
		$userBounds->{$rxnbnds->[$i]->reaction()->id()}->{$rxnbnds->[$i]->modelcompartment()->label()}->{$translation->{$rxnbnds->[$i]->variableType()}} = {
			max => $rxnbnds->[$i]->upperBound(),
			min => $rxnbnds->[$i]->lowerBound()
		};
	}
	my $dataArrays;
	foreach my $var (keys(%{$userBounds})) {
		foreach my $comp (keys(%{$userBounds->{$var}})) {
			foreach my $type (keys(%{$userBounds->{$var}->{$comp}})) {
				push(@{$dataArrays->{var}},$var);
				push(@{$dataArrays->{type}},$type);
				push(@{$dataArrays->{min}},$userBounds->{$var}->{$comp}->{$type}->{min});
				push(@{$dataArrays->{max}},$userBounds->{$var}->{$comp}->{$type}->{max});
				push(@{$dataArrays->{comp}},$comp);
			}
		}
	}
	my $mediaData = [
		"ID\tNAMES\tVARIABLES\tTYPES\tMAX\tMIN\tCOMPARTMENTS",
		$self->media()->name()."\t".
		$self->media()->name()."\t".
		join("|",@{$dataArrays->{var}})."\t".
		join("|",@{$dataArrays->{type}})."\t".
		join("|",@{$dataArrays->{max}})."\t".
		join("|",@{$dataArrays->{min}})."\t".
		join("|",@{$dataArrays->{comp}})
	];
	ModelSEED::utilities::PRINTFILE($directory."media.tbl",$mediaData);
	#Set StringDBFile.txt
	my $dataDir = ModelSEED::utilities::MODELSEEDCORE()."data/";
	my $stringdb = [
		"Name\tID attribute\tType\tPath\tFilename\tDelimiter\tItem delimiter\tIndexed columns",
		"compound\tid\tSINGLEFILE\t".$dataDir."ReactionDB/compounds/\t".$dataDir."fbafiles/compoundDataFile.tbl\tTAB\tSC\tid",
		"reaction\tid\tSINGLEFILE\t".$directory."reaction/\t".$dataDir."fbafiles/reactionDataFile.tbl\tTAB\t|\tid",
		"cue\tNAME\tSINGLEFILE\t\t".$dataDir."ReactionDB/MFAToolkitInputFiles/cueTable.txt\tTAB\t|\tNAME",
		"media\tID\tSINGLEFILE\t".$dataDir."ReactionDB/Media/\t".$directory."media.tbl\tTAB\t|\tID;NAMES"		
	];
	ModelSEED::utilities::PRINTFILE($directory."StringDBFile.txt",$stringdb);
	#Write shell script
	my $exec = [
		"source ".ModelSEED::utilities::MODELSEEDCORE()."/bin/source-me.sh",
		ModelSEED::utilities::MODELSEEDCORE().'/software/mfatoolkit/bin/mfatoolkit resetparameter "MFA input directory" '.$dataDir.'ReactionDB/ parameterfile "../Parameters/ProductionMFA.txt" parameterfile "'.$directory.'SpecializedParameters.txt" LoadCentralSystem "'.$directory.'Model.tbl" > "'.$directory.'log.txt"'
	];
	ModelSEED::utilities::PRINTFILE($directory."runMFAToolkit.sh",$exec);
	chmod 0775,$directory."runMFAToolkit.sh";
}

__PACKAGE__->meta->make_immutable;
1;
