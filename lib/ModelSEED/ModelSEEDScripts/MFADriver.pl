#!/usr/bin/perl -w

########################################################################
# Driver script for metabolic flux analysis tools builts to analyze metabolic models
# Author: Christopher Henry
# Author email: chrisshenry@gmail.com
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 11/08/2008
########################################################################

use strict;
use FIGMODEL;
$|=1;

#First checking to see if at least one argument has been provided
if (!defined($ARGV[0]) || $ARGV[0] eq "help") {
    print "MFATOOLPACK INSTRUCTIONS\n";
    print "DEFAULT SYNTAX:\n";
    print "./MFA.sh (name of model)\n";
    print "EXAMPLE: ./MFA.sh Core83333.1\n\n";
    print "OPTIONAL ARGUMENTS:\n";
    print "1.) MEDIA SPECIFICATION:\n";
    print "\tSYNTAX: m:(Media name) or m:(comma delimited list of compounds in the media)\n";
    print "\tDEFAULT: If no 'm:' argument is provided, complete media is used.\n";
    print "\tEXAMPLE 1: 'runmfa Core83333.1 m:ArgonneLBMedia'\n";
    print "\thttp://bioseed.mcs.anl.gov/~chenry/FIG/CGI/seedviewer.cgi?page=MediaViewer\n";
    print "\tEXAMPLE 2: 'runmfa Core83333.1 m:cpd00027,cpd00013,cpd00009,cpd00048,cpd00063,cpd00011,cpd10516,cpd00067,cpd00001,cpd00205,cpd00254,cpd00971,cpd00007'\n\n";
    print "2.) KNOCKOUT SPECIFICATION:\n";
    print "\tSYNTAX: ko:(comma delimited list of reactions or genes)\n";
    print "\tEXAMPLE 1: 'runmfa Core83333.1 ko:rxn00001,rxn00002'\n";
    print "\tEXAMPLE 2: 'runmfa Core83333.1 ko:peg.1'\n\n";
    print "3.) OBJECTIVE SPECIFICATION:\n";
    print "\tSYNTAX: o:(objective for mfa or type of study to be run)\n";
    print "\tDEFAULT: IF no 'o:' is provided, biomass is maximized.\n";
    print "\tEXAMPLE 1: 'runmfa Core83333.1 o:classify' classifies reactions\n";
    print "\tEXAMPLE 2: 'runmfa Core83333.1 o:singleko' simulates ko of every gene\n";
    print "\tEXAMPLE 3: 'runmfa Core83333.1 o:rxn00001' maximizes the flux through rxn00001\n";
    print "\tEXAMPLE 4: 'runmfa Core83333.1 o:cpd00008' maximizes the production of cpd00008\n";
    print "\tEXAMPLE 5: 'runmfa Core83333.1 o:REACT-bio00007' maximizes production of each biomass component\n";
    print "\tEXAMPLE 6: 'runmfa Core83333.1 o:REACT-rxn00001' maximizes production of each rxn00001 reactant\n\n";
}

#Creating model object which is almost certain to be necessary
my $model = new FIGMODEL->new();

#Checking out a filename for this run
my $Filename = $model->filename();

#Searching for recognized arguments
my $ModelName = "NONE";
my $Media = "Complete";
my $ReactionKO = "none";
my $GeneKO = "none";
my $Objective = "DEFAULT";
my $Parameters = "";
for (my $i=0; $i < @ARGV; $i++) {
    my @Temp = split(/:/,$ARGV[$i]);
    if (@Temp == 1) {
	$ModelName = $Temp[0];
    } elsif ($Temp[0] =~ m/^m/) {
	$Media = $Temp[1];
    } elsif ($Temp[0] =~ m/^o/) {
	$Objective = $Temp[1];
    } elsif ($Temp[0] =~ m/^p/) {
	$Parameters = $Temp[1];
    } elsif ($Temp[0] =~ m/^ko/) {
	my @KOList = split(/,/,$Temp[1]);
	foreach my $Object (@KOList) {
	    if ($Object =~ m/rxn\d\d\d\d\d/) {
		if ($ReactionKO eq "none") {
		    $ReactionKO = $Object;
		} else {
		    $ReactionKO .= ",".$Object;
		}
	    } elsif ($Object =~ m/peg\.\d+/) {
		if ($GeneKO eq "none") {
		    $GeneKO = $Object;
		} else {
		    $GeneKO .= ",".$Object;
		}
	    }
	}
    }
}

$model->{"MFAToolkit executable"}->[0] .= ' resetparameter MFASolver GLPK';

#Filling out the parameters argument
if (length($Parameters) > 0) {
    $Parameters = ' parameterfile Parameters/'.$Parameters.".txt";
}

#Checking that a model has been input
if ($ModelName eq "NONE") {
    print "ERROR: no model has been provided!\n";
    exit(0);
}

my $Directory = "";
my $Extension = "";
if ($ModelName ne "Complete") {
    $Extension = ".txt";
    #Getting the directory for the model
    ($Directory,$ModelName) = $model->GetDirectoryForModel($ModelName);
    if (length($Directory) == 0) {
        print "ERROR: input model name ".$ModelName." not found in the database!\n";
    }
}

#Checking if this is custom media and creating the custom media file if it is
my $CustomMedia = 0;
if ($Media =~ m/^cpd\d\d\d\d\d/) {
    $CustomMedia = 1;
    my @CompoundList = split(/,/,$Media);
    my $MediaFilename = $model->{"Media directory"}->[0].$Filename.".txt";
    if (open (MEDIAOUTPUT, ">$MediaFilename")) {
	print MEDIAOUTPUT "VarName;VarType;VarCompartment;Min;Max\n";
	foreach my $Compound (@CompoundList) {
	    if ($Compound =~ m/^cpd\d\d\d\d\d$/) {
		print MEDIAOUTPUT $Compound.";DRAIN_FLUX;e;-100;100\n";
	    }
	}
	close(MEDIAOUTPUT);
    }
    $Media = $Filename;
}

#Checking if the media file exists
if ($Media ne "Complete" && $Media ne "NONE" && !(-e $model->{"Media directory"}->[0].$Media.".txt")) {
    print "ERROR: specified media file ".$Media." not found!\n";
    exit(0);
}

#Setting the command line arguments for the media
my $MediaCommandLineArgument;
if ($Media eq "Complete") {
    $MediaCommandLineArgument = ' resetparameter "Default max drain flux" 100 resetparameter "user bounds filename" "Media/NoBounds.txt"';
} elsif ($Media eq "NONE") {
    $MediaCommandLineArgument = "";
} else {
    $MediaCommandLineArgument = ' resetparameter "user bounds filename" "Media/'.$Media.'.txt"';
}
#Setting the command line arguments for the KO
my $KOCommandLineArgument = ' resetparameter "Reactions to knockout" "'.$ReactionKO.'" resetparameter "Genes to knockout" "'.$GeneKO.'"';

#Running the MFA toolkit with various parameters depending on what the objective is
if ($Objective eq "classify") {
    #Classifying the reactions in the model
    my $ObjectiveArguments = ' resetparameter "find tight bounds" 1';
    system($model->{"MFAToolkit executable"}->[0].' parameterfile Parameters/ProductionMFA.txt'.$Parameters.$ObjectiveArguments.$KOCommandLineArgument.$MediaCommandLineArgument.' resetparameter output_folder "'.$Filename.'/" LoadCentralSystem "'.$Directory.$ModelName.$Extension.'" > '.$model->{"MFAToolkit output directory"}->[0].$Filename.'/RunOutput.log');
    &PrintReactionClasses($Filename);
} elsif ($Objective eq "singleko") {    
    #knocking out each individual gene
    my $ObjectiveArguments = ' resetparameter "perform single KO experiments" 1';
    system($model->{"MFAToolkit executable"}->[0].' parameterfile Parameters/ProductionMFA.txt'.$Parameters.$ObjectiveArguments.$KOCommandLineArgument.$MediaCommandLineArgument.' resetparameter output_folder "'.$Filename.'/" LoadCentralSystem "'.$Directory.$ModelName.$Extension.'" > '.$model->{"MFAToolkit output directory"}->[0].$Filename.'/RunOutput.log');
    &PrintGeneKOResults($Filename);
} elsif ($Objective =~ /cpd\d\d\d\d\d/) {
    #Maximizing production of a single compound
    my $ObjectiveArguments = ' resetparameter "maximize individual metabolite production" 1 resetparameter "maximize single objective" 0 resetparameter "metabolites to optimize" "'.$Objective.'"';
    system($model->{"MFAToolkit executable"}->[0].' parameterfile Parameters/ProductionMFA.txt'.$Parameters.$ObjectiveArguments.$KOCommandLineArgument.$MediaCommandLineArgument.' resetparameter output_folder "'.$Filename.'/" LoadCentralSystem "'.$Directory.$ModelName.$Extension.'" > '.$model->{"MFAToolkit output directory"}->[0].$Filename.'/RunOutput.log');    
    &PrintSolution($Filename);
} elsif ($Objective =~ /(rxn\d\d\d\d\d)/ || $Objective =~ /(bio\d\d\d\d\d)/) {
    my $Reaction = $1;
    my $ObjectiveArguments;
    if ($Objective =~ /^rxn\d\d\d\d\d$/ || $Objective =~ /^bio\d\d\d\d\d$/) {
	#Maximizing flux of a single reaction
	$ObjectiveArguments = ' resetparameter "objective" "MAX;FLUX;'.$Reaction.';none;1"';
	system($model->{"MFAToolkit executable"}->[0].' parameterfile Parameters/ProductionMFA.txt'.$Parameters.$ObjectiveArguments.$KOCommandLineArgument.$MediaCommandLineArgument.' resetparameter output_folder "'.$Filename.'/" LoadCentralSystem "'.$Directory.$ModelName.$Extension.'" > '.$model->{"MFAToolkit output directory"}->[0].$Filename.'/RunOutput.log');
	&PrintSolution($Filename);
    } else {
	#Maximizing production of each reactant of a reaction
	$ObjectiveArguments = ' resetparameter "maximize individual metabolite production" 1 resetparameter "maximize single objective" 0 resetparameter "metabolites to optimize" "REACTANTS;'.$Reaction.'"';
	system($model->{"MFAToolkit executable"}->[0].' parameterfile Parameters/ProductionMFA.txt'.$Parameters.$ObjectiveArguments.$KOCommandLineArgument.$MediaCommandLineArgument.' resetparameter output_folder "'.$Filename.'/" LoadCentralSystem "'.$Directory.$ModelName.$Extension.'" > '.$model->{"MFAToolkit output directory"}->[0].$Filename.'/RunOutput.log');
	&PrintReactantOptimizationResults($Filename);
    }
} else {
    #Default objective
    system($model->{"MFAToolkit executable"}->[0].' parameterfile Parameters/ProductionMFA.txt'.$Parameters.$KOCommandLineArgument.$MediaCommandLineArgument.' resetparameter output_folder "'.$Filename.'/" LoadCentralSystem "'.$Directory.$ModelName.$Extension.'" > '.$model->{"MFAToolkit output directory"}->[0].$Filename.'/RunOutput.log');	
    &PrintSolution($Filename);
}

#Clearing out the result directory
#$model->cleardirectory($Filename);

#Deleting the custom media that may have been created
if ($CustomMedia == 1) {
    unlink $model->{"Media directory"}->[0].$Media.".txt";
}

sub PrintSolution {
    my($Filename) = @_;
    if (-e $model->{"MFAToolkit output directory"}->[0].$Filename."/MFAOutput/SolutionReactionData0.txt") {
	system('cat '.$model->{"MFAToolkit output directory"}->[0].$Filename."/MFAOutput/SolutionReactionData0.txt");
    } else {
	print "Solution reaction data not found!\n";
    }
    if (-e $model->{"MFAToolkit output directory"}->[0].$Filename."/MFAOutput/SolutionCompoundData0.txt") {
	system('cat '.$model->{"MFAToolkit output directory"}->[0].$Filename."/MFAOutput/SolutionCompoundData0.txt");
    } else {
	print "Solution compound data not found!\n";
    }
}

sub PrintGeneKOResults {
    my($Filename) = @_;
    #Parsing deletion output file
    if (-e $model->{"MFAToolkit output directory"}->[0].$Filename."/DeletionStudyResults.txt") {
	my $DeletionData = FIGMODEL::LoadMultipleLabeledColumnFile($model->{"MFAToolkit output directory"}->[0].$Filename."/DeletionStudyResults.txt",";","");
	print "Gene;Insilico growth fraction;Reactions knocked out\n";
	for (my $i=1; $i < @{$DeletionData}; $i++) {
	    if (defined($DeletionData->[$i]->{"Experiment"}) && defined($DeletionData->[$i]->{"Insilico growth"}) && defined($DeletionData->[$i]->{"Reactions"})) {
		print $DeletionData->[$i]->{"Experiment"}->[0].";".$DeletionData->[$i]->{"Insilico growth"}->[0].";".$DeletionData->[$i]->{"Reactions"}->[0]."\n";
	    }
	}
    } else {
	print "Deletion study results data not found!\n";
    }
}

sub PrintReactionClasses {
    my($Filename) = @_;
    #Parsing reaction tight bounds output file
    if (-e $model->{"MFAToolkit output directory"}->[0].$Filename."/MFAOutput/TightBoundsReactionData0.txt") {
	my $TightBoundData = FIGMODEL::LoadMultipleLabeledColumnFile($model->{"MFAToolkit output directory"}->[0].$Filename."/MFAOutput/TightBoundsReactionData0.txt",";","");
	print "Reaction ID;Class;Minimum flux;Maximum flux\n";
	for (my $i=1; $i < @{$TightBoundData}; $i++) {
	    if (defined($TightBoundData->[$i]->{"DATABASE ID"}) && defined($TightBoundData->[$i]->{"FLUX MIN"}) && defined($TightBoundData->[$i]->{"FLUX MAX"})) {
		my $Class;
		if ($TightBoundData->[$i]->{"FLUX MIN"}->[0] > 0.00000001) {
		    $Class = "Positive";
		} elsif ($TightBoundData->[$i]->{"FLUX MAX"}->[0] < -0.00000001) {
		    $Class = "Negative";
		} elsif ($TightBoundData->[$i]->{"FLUX MIN"}->[0] < -0.00000001) {
		    if ($TightBoundData->[$i]->{"FLUX MAX"}->[0] > 0.00000001) {
			$Class = "Variable";
		    } else {
			$Class = "Negative variable";
		    }
		} elsif ($TightBoundData->[$i]->{"FLUX MAX"}->[0] > 0.00000001) {
		    $Class = "Positive variable";
		} else {
		    $Class = "Blocked";
		}
		print $TightBoundData->[$i]->{"DATABASE ID"}->[0].";".$Class.";".$TightBoundData->[$i]->{"FLUX MIN"}->[0].";".$TightBoundData->[$i]->{"FLUX MAX"}->[0]."\n";
	    }
	}
    } else {
	print "Reaction classification data not found!\n";
    }
    if (-e $model->{"MFAToolkit output directory"}->[0].$Filename."/"."MFAOutput/TightBoundsCompoundData0.txt") {
	my $TightBoundData = FIGMODEL::LoadMultipleLabeledColumnFile($model->{"MFAToolkit output directory"}->[0].$Filename."/MFAOutput/TightBoundsCompoundData0.txt",";","");
	print "Compound ID;Class;Minimum uptake;Maximum uptake\n";
	for (my $i=1; $i < @{$TightBoundData}; $i++) {
	    if (defined($TightBoundData->[$i]->{"DATABASE ID"}) && defined($TightBoundData->[$i]->{"UPTAKE MIN"}) && defined($TightBoundData->[$i]->{"UPTAKE MAX"})) {
		my $Class;
		if ($TightBoundData->[$i]->{"UPTAKE MIN"}->[0] > 0.00000001) {
		    $Class = "Positive";
		} elsif ($TightBoundData->[$i]->{"UPTAKE MAX"}->[0] < -0.00000001) {
		    $Class = "Negative";
		} elsif ($TightBoundData->[$i]->{"UPTAKE MIN"}->[0] < -0.00000001) {
		    if ($TightBoundData->[$i]->{"UPTAKE MAX"}->[0] > 0.00000001) {
			$Class = "Variable";
		    } else {
			$Class = "Negative variable";
		    }
		} elsif ($TightBoundData->[$i]->{"UPTAKE MAX"}->[0] > 0.00000001) {
		    $Class = "Positive variable";
		} else {
		    $Class = "Blocked";
		}
		print $TightBoundData->[$i]->{"DATABASE ID"}->[0].";".$Class.";".$TightBoundData->[$i]->{"UPTAKE MIN"}->[0].";".$TightBoundData->[$i]->{"UPTAKE MAX"}->[0]."\n";
	    }
	}
    } else {
	print "Nutrient classification data not found!\n";
    }
}

sub PrintReactantOptimizationResults {
    my($Filename) = @_;
    if (-e $model->{"MFAToolkit output directory"}->[0].$Filename."/MFAOutput/ProblemReports.txt") {
	my $ProblemReportData = FIGMODEL::LoadMultipleLabeledColumnFile($model->{"MFAToolkit output directory"}->[0].$Filename."/MFAOutput/ProblemReports.txt",";","");
	my $ResultString;
	for (my $i=(@{$ProblemReportData}-1); $i >=0; $i--) {
	    if (defined($ProblemReportData->[$i]->{"Individual metablite production"}) && length($ProblemReportData->[$i]->{"Individual metablite production"}->[0]) > 0) {
		$ResultString = $ProblemReportData->[$i]->{"Individual metablite production"}->[0];
		last;
	    }
	}
	if (length($ResultString) == 0) {
	    print "Deletion study results data not found!\n";
	} else {
	    print "Compound;Max production\n";
	    my @CompoundResults = split(/\|/,$ResultString);
	    foreach my $Compound (@CompoundResults) {
		$Compound =~ s/:/;/;
		print $Compound."\n";
	    }
	}
    } else {
	print "Deletion study results data not found!\n";
    }
}