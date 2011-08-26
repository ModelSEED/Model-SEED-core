#!/usr/bin/perl -w

########################################################################
# Driver script for the model database interaction module
# Author: Christopher Henry
# Author email: chrisshenry@gmail.com
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 8/26/2008
########################################################################

use strict;
use FIGMODEL;
use LWP::Simple;
$|=1;

#First checking to see if at least one argument has been provided
if (!defined($ARGV[0]) || $ARGV[0] eq "help") {
    print "Function name must be specified as input arguments!\n";;
	exit(0);
}

#This variable will hold the name of a file that will be printed when a job finishes
my $FinishedFile = "NONE";
my $Status = "SUCCESS";

#Searching for recognized arguments
my $driv = driver->new();
for (my $i=0; $i < @ARGV; $i++) {
    $ARGV[$i] =~ s/___/ /g;
    $ARGV[$i] =~ s/\.\.\./(/g;
    $ARGV[$i] =~ s/,,,/)/g;
    print "\nProcessing argument: ".$ARGV[$i]."\n";
    if ($ARGV[$i] =~ m/^finish\?(.+)/) {
        $FinishedFile = $1;
    } else {
        #Splitting argument
        my @Data = split(/\?/,$ARGV[$i]);
        my $FunctionName = $Data[0];

        #Calling function
        $Status .= $driv->$FunctionName(@Data);
    }
}

#Printing the finish file if specified
if ($FinishedFile ne "NONE") {
    if ($FinishedFile =~ m/^\//) {
        FIGMODEL::PrintArrayToFile($FinishedFile,[$Status]);
    } else {
        FIGMODEL::PrintArrayToFile($driv->{_figmodel}->{"database message file directory"}->[0].$FinishedFile,[$Status]);
    }
}

exit();

package driver;

sub new {
	my $self = {_figmodel => FIGMODEL->new()};
    return bless $self;
}

#Individual subroutines are all listed here
sub addstrains {
    my($self,@Data) = @_;

    if (@Data < 2) {
        print "Syntax for this command: addstrains?(Definition filename).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    my $DefinitionTable = FIGMODELTable::load_table($self->{_figmodel}->{"interval directory"}->[0].$Data[1],"\t","|",0,["Strain"]);
    my $RankTable = FIGMODELTable::load_table($self->{_figmodel}->{"interval directory"}->[0]."IntervalRanks.txt","\t","|",0,["Rank","Interval"]);
    my $CurrentStrainTable = $self->{_figmodel}->GetDBTable("STRAIN TABLE");

    my $Date = time();
    for (my $i=0; $i < $DefinitionTable->size(); $i++) {
        my $Strain = $DefinitionTable->get_row($i);
        my $IntervalList;
        my $Base = "None";
        my $Growth;
        if (defined($Strain->{"ArgonneLBMedia"}->[0])) {
            push(@{$Growth},"ArgonneLBMedia:".$Strain->{"ArgonneLBMedia"}->[0]);
        }
        if (defined($Strain->{"ArgonneNMSMedia"}->[0])) {
            push(@{$Growth},"ArgonneNMSMedia:".$Strain->{"ArgonneNMSMedia"}->[0]);
        }
        my @IntervalRanks = split(/\./,$Strain->{"Strain"}->[0]);
        for (my $j=0; $j < @IntervalRanks; $j++) {
            my $Row = $RankTable->get_row_by_key($IntervalRanks[$j],"Rank");
            if (defined($Row->{"Interval"}->[0])) {
                push(@{$IntervalList},$Row->{"Interval"}->[0]);
            }
        }
        if (@IntervalRanks > 2) {
            $Base = $IntervalRanks[0];
            for (my $j=1; $j < (@IntervalRanks-1); $j++) {
                $Base .= ".".$IntervalRanks[$j];
            }
        }
        $CurrentStrainTable->add_row({"ID" => [$Strain->{"Strain"}->[0]],"INTERVALS" => $IntervalList, "GROWTH" => $Growth,"BASE" => [$Base],"OWNER" => ["ALL"],"DATE" => [$Date]});
    }

    $CurrentStrainTable->save();

    return "SUCCESS";
}

sub parsenfsimoutput {
	my($self,@Data) = @_;

    if (@Data < 2) {
        print "Syntax for this command: parsenfsimoutput?(NFSim output file name).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

	my $Output;
	my $cache;
	my $Filename = $Data[1];
	if (open (INPUT, "<$Filename")) {
		while (my $Line = <INPUT>) {
			chomp($Line);
			if ($Line =~ m/Sim\stime:\s(.+)\tCPU\stime:\s(.+)s\s\sevents/) {
				my $SimTime = $1;
				my $CPUTime = $2;
				my $Position = int(($SimTime/0.5) + 0.5);
				push(@{$Output->[$Position]},$CPUTime);
				push(@{$cache},[$CPUTime,$Position]);
				#print $SimTime."\t".$CPUTime."\t".$Position."\n";
			}
		}
		close(INPUT);
	}

	FIGMODEL::PrintTwoDimensionalArrayToFile("/home/chenry/CpuTimePerSimTime.txt",$Output,";");

	@{$cache} = sort { $a->[0] <=> $b->[0] } @{$cache};

	my $Results;
	my $Increment = 3600*24;
	my $CurrentTime = $Increment;
	my $CurrentData = [0];
	foreach my $Line (@{$cache}) {
		if ($Line->[1] > 0) {
			$CurrentData->[$Line->[1]-1]--;
		}
		$CurrentData->[$Line->[1]]++;
		if ($Line->[0] >  $CurrentTime) {
			my $CurrentLine = [$Line->[0]];
			push(@{$CurrentLine},@{$CurrentData});
			push(@{$Results},$CurrentLine);
			$CurrentTime += $Increment;
		}
	}

	FIGMODEL::PrintTwoDimensionalArrayToFile("/home/chenry/SimTimePerCpuTime.txt",$Results,";");
}

sub createnobiologmodels {
	my($self,@Data) = @_;

    if (@Data < 2) {
        print "Syntax for this command: createnobiologmodels?(Model list filename).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

	my $ModelList = FIGMODEL::LoadSingleColumnFile($Data[1],"");
	foreach my $Model (@{$ModelList}) {
		my $ModelTable = $self->{_figmodel}->database()->GetDBModel($Model);
		if (defined($ModelTable)) {
			my $ModelData = $self->{_figmodel}->GetModelData($Model);
			my $Count = 0;
			for (my $i=0; $i < $ModelTable->size(); $i++) {
				my $Row = $ModelTable->get_row($i);
				if (defined($Row->{"ASSOCIATED PEG"}->[0]) && $Row->{"ASSOCIATED PEG"}->[0] =~ m/BIOLOG/) {
					$ModelTable->delete_row($ModelTable->row_index($Row));
					$i--;
					$Count++;
				}
			}
			if ($Count > 0) {
				print $Count."\n";
				#$ModelTable->save($ModelData->{"DIRECTORY"}->[0].$Model."VNoBiolog.txt");
				#my ($FalsePostives,$FalseNegatives,$CorrectNegatives,$CorrectPositives,$ErrorVector,$HeadingVector) = $self->{_figmodel}->RunAllStudiesWithDataFast($Model,"All",undef,"VNoBiolog");
			}
		}
	}
}

sub renamemodels {
	my($self,@Data) = @_;

	my @Directories = glob("/vol/model-dev/MODEL_DEV_DB/Models/*");

	foreach my $Directory (@Directories) {
		print $Directory."\n";
		my $GenomeID;
		if ($Directory =~ m/\/([^\/]+)$/) {
			$GenomeID = $1;
		}

		my @Files = glob($Directory."/*");
		foreach my $File (@Files) {
			my $ModelID = "Core".$GenomeID;
			if ($File =~ m/$ModelID/) {
				my $Filename = substr($File,length($Directory)+1);
				$Filename =~ s/Core/Seed/;
				#print "mv ".$File." ".$Directory."/".$Filename."\n";
				#print "rm ".$File."\n";
				system("mv ".$File." ".$Directory."/".$Filename);
			}
		}
		#last;
	}
}

sub removefig {
	my($self,@Data) = @_;

	my $ModelList;
	if ($Data[1] =~ m/LIST-(.+)/) {
		$ModelList = $self->{_figmodel}->database()->load_single_column_file($1,"");
	} else {
		$ModelList = [$Data[1]];
	}
	for (my $i=0; $i < @{$ModelList}; $i++) {
		my $ModelData = $self->{_figmodel}->GetModelData("Seed".$ModelList->[$i]);
		my $filename = $ModelData->{"DIRECTORY"}->[0]."Seed".$ModelList->[$i].".txt";
		my $ModelArray = $self->{_figmodel}->database()->load_single_column_file($filename,"");
		for (my $j=0; $j < @{$ModelArray}; $j++) {
			if ($ModelArray->[$j] =~ m/^bio\d\d\d\d\d/) {
				$ModelArray->[$j] =~ s/bio\d\d\d\d\d/bio00060/;
			}
		}
		FIGMODEL::PrintArrayToFile($filename,$ModelArray);
	}
}
