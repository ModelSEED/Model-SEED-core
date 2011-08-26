#!/usr/bin/perl -w

########################################################################
# Script for loading functional role to reaction mapping table in the SEED
# Author: Christopher Henry
# Author email: chrisshenry@gmail.com
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 10/15/2008
########################################################################

use strict;
use FIGMODEL;
$|=1;

#All data will be placed in this reference to an array of hashes
my %ReactionHash;
my %Roles;
my $ReactionMap;

#Creating the FIG object
my $fig = new FIG;

#Loading reaction translation
my $model = new FIGMODEL->new();
$model->LoadReactionTranslationData();

my $Filename = "/vol/seed-data-scratch/Data.scratch/ReactionDB/masterfiles/BSubFunctions.txt";
my ($PegToFunction,$HashReferenceReverse) = FIGMODEL::LoadSeparateTranslationFiles($Filename,"\t");

#Loading the B. subtilis model mappings
print "PARSING BSUBTILIS MODEL\n\n";
my ($Directory,$Model) = $model->GetDirectoryForModel("iBsu1121");
my $Data = FIGMODEL::LoadMultipleLabeledColumnFile($Directory."iBsu1121.txt",";","",1);
#Getting the B subtilis annotations
my $GenomeData = $fig->all_features_detailed_fast("224308.1");
my %PegFunctions;
print "GENE\tORIGINAL FUNCTION\tNEW FUNCTION\n";
for (my $j=0; $j < @{$GenomeData}; $j++) {
    #id, location, aliases, type, minloc, maxloc, assigned_function, made_by, quality
    if (defined($GenomeData->[$j]->[0]) && defined($GenomeData->[$j]->[6]) && $GenomeData->[$j]->[0] =~ m/(peg.\d+)/) {
        my $Gene = $1;
	if (defined($PegToFunction->{$Gene})) {
	    if ($PegToFunction->{$Gene} ne $GenomeData->[$j]->[6]) {
		print $Gene."\t".$PegToFunction->{$Gene}."\t".$GenomeData->[$j]->[6]."\n";
	    }
	    my @Roles = $model->ParseFunctionIntoRoles($PegToFunction->{$Gene});
	    for (my $k=0; $k < @Roles;$k++) {
		push(@{$PegFunctions{$Gene}},$Roles[$k]);
	    }
	} else {
	    if ($GenomeData->[$j]->[6] ne "unknown" && $GenomeData->[$j]->[6] ne "hypothetical protein") {
		print $Gene."\tNONE\t".$GenomeData->[$j]->[6]."\n";
	    }
	}
    }
}

#Setting mappings from the genes assigned to the reactions
my $ComplexIndex = 0;
for (my $i=0; $i < @{$Data};$i++) {
    if (defined($Data->[$i]->{"LOAD"}) && defined($Data->[$i]->{"ASSOCIATED PEG"})) {
	my $Reaction = $Data->[$i]->{"LOAD"}->[0];
	#Parsing the pegs
	my @PegSetArray = split(/\|/,$Data->[$i]->{"ASSOCIATED PEG"}->[0]);
	for (my $j=0; $j < @PegSetArray; $j++) {
	    my @SinglePegs = split(/\+/,$PegSetArray[$j]);
	    for (my $k=0; $k < @SinglePegs; $k++) {
		if (defined($PegFunctions{$SinglePegs[$k]})) {
		    for (my $m=0; $m < @{$PegFunctions{$SinglePegs[$k]}};$m++) {
			if (defined($ReactionHash{$Reaction}->{$PegFunctions{$SinglePegs[$k]}->[$m]})) {
			    my @Subsystems = keys(%{$ReactionHash{$Reaction}->{$PegFunctions{$SinglePegs[$k]}->[$m]}});
			    for (my $n=0; $n < @Subsystems; $n++) {
				$ReactionHash{$Reaction}->{$PegFunctions{$SinglePegs[$k]}->[$m]}->{$Subsystems[$n]}->{"SOURCE"} .= "|"."iBsu1121";
				$ReactionHash{$Reaction}->{$PegFunctions{$SinglePegs[$k]}->[$m]}->{$Subsystems[$n]}->{"MASTER"} = 1;
				if (!defined($ReactionHash{$Reaction}->{$PegFunctions{$SinglePegs[$k]}->[$m]}->{$Subsystems[$n]}->{"COMPLEX"})) {
				    $ReactionHash{$Reaction}->{$PegFunctions{$SinglePegs[$k]}->[$m]}->{$Subsystems[$n]}->{"COMPLEX"} = $ComplexIndex;
				}
			    }
			} else {
			    my @SubsystemList = $fig->role_to_subsystems($PegFunctions{$SinglePegs[$k]}->[$m]);
			    for (my $n=0; $n < @SubsystemList;$n++) {
				my $Class = $fig->subsystem_classification($SubsystemList[$n]);
				my $SubsystemClass = $fig->subsystem_classification($SubsystemList[$n]);
				if ($SubsystemClass->[0] !~ m/Experimental Subsystems/ && $SubsystemClass->[0] !~ m/Clustering-based subsystems/ && length($SubsystemClass->[0]) > 0) {
				    $ReactionHash{$Reaction}->{$PegFunctions{$SinglePegs[$k]}->[$m]}->{$SubsystemList[$n]}->{"CLASS 1"} = $SubsystemClass->[0];
				    $ReactionHash{$Reaction}->{$PegFunctions{$SinglePegs[$k]}->[$m]}->{$SubsystemList[$n]}->{"CLASS 2"} = $SubsystemClass->[1];
				    $ReactionHash{$Reaction}->{$PegFunctions{$SinglePegs[$k]}->[$m]}->{$SubsystemList[$n]}->{"SOURCE"} = "iBsu1121";
				    $ReactionHash{$Reaction}->{$PegFunctions{$SinglePegs[$k]}->[$m]}->{$SubsystemList[$n]}->{"MASTER"} = 1;
				    $ReactionHash{$Reaction}->{$PegFunctions{$SinglePegs[$k]}->[$m]}->{$SubsystemList[$n]}->{"COMPLEX"} = $ComplexIndex;
				}
			    }
			}
		    }
		} else {
		    print "Problem with ".$SinglePegs[$k]."\n";
		}
	    }
	    $ComplexIndex++;
	}
    }
}

#Printing the table to file
$Filename = "/home/chenry/BSubMapping.txt";
open (FUNCTIONOUTPUT, ">$Filename");
print FUNCTIONOUTPUT "PRINTING TABLE\n\n";
print FUNCTIONOUTPUT "REACTION\tROLE\tSUBSYSTEM\tSOURCE\tDATE\tNOTES\tCOMPLEX\tMASTER\n";
my @ReactionList = keys(%ReactionHash);
for (my $i=0; $i < @ReactionList; $i++) {
    my @FunctionList = keys(%{$ReactionHash{$ReactionList[$i]}});
    for (my $j=0; $j < @FunctionList; $j++) {
	my @SubsystemList = keys(%{$ReactionHash{$ReactionList[$i]}->{$FunctionList[$j]}});
	for (my $k=0; $k < @SubsystemList; $k++) {
	    if (!defined($ReactionHash{$ReactionList[$i]}->{$FunctionList[$j]}->{$SubsystemList[$k]}->{"COMPLEX"})) {
		$ReactionHash{$ReactionList[$i]}->{$FunctionList[$j]}->{$SubsystemList[$k]}->{"COMPLEX"} = $ComplexIndex;
		$ComplexIndex++;
	    }
	    my @Complexes = split(/\|/,$ReactionHash{$ReactionList[$i]}->{$FunctionList[$j]}->{$SubsystemList[$k]}->{"COMPLEX"});
	    for (my $m=0; $m < @Complexes; $m++) {
		print FUNCTIONOUTPUT $ReactionList[$i]."\t".$FunctionList[$j]."\t".$SubsystemList[$k]."\t";
		print FUNCTIONOUTPUT $ReactionHash{$ReactionList[$i]}->{$FunctionList[$j]}->{$SubsystemList[$k]}->{"SOURCE"}."\t";
		print FUNCTIONOUTPUT FIGMODEL::Date()."\t";
		if (defined($ReactionHash{$ReactionList[$i]}->{$FunctionList[$j]}->{$SubsystemList[$k]}->{"NOTES"})) {
		    print FUNCTIONOUTPUT $ReactionHash{$ReactionList[$i]}->{$FunctionList[$j]}->{$SubsystemList[$k]}->{"NOTES"};
		}
		print FUNCTIONOUTPUT "\t".$Complexes[$m]."\t";
		print FUNCTIONOUTPUT $ReactionHash{$ReactionList[$i]}->{$FunctionList[$j]}->{$SubsystemList[$k]}->{"CLASS 1"}."\t";
		print FUNCTIONOUTPUT $ReactionHash{$ReactionList[$i]}->{$FunctionList[$j]}->{$SubsystemList[$k]}->{"CLASS 2"}."\t";
		print FUNCTIONOUTPUT $ReactionHash{$ReactionList[$i]}->{$FunctionList[$j]}->{$SubsystemList[$k]}->{"MASTER"}."\n";
	    }
	}
    }
}
close(FUNCTIONOUTPUT);


undef $fig;