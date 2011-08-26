#!/usr/bin/perl -w

########################################################################
# Driver script for the model database interaction module
# Author: Christopher Henry
# Author email: chrisshenry@gmail.com
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 8/26/2008
########################################################################

use strict;
use FileIOFunctions;

if (!defined($ARGV[0]) || !defined($ARGV[1]) || !defined($ARGV[2]) || !defined($ARGV[3])) {
	print "Three arguements must be provided: start stop script outputpath\n";
}

my $Start = $ARGV[0];
my $Stop = $ARGV[1];
my $Script = $ARGV[2];
my $Outputpath = $ARGV[3];

my $CombinedOutput;
for (my $i=$Start; $i < $Stop; $i++) {
	if ($Script eq "COMBINE") {
		my $Input = LoadSingleColumnFile($Outputpath.$i.".txt","");
		for (my $j=0; $j < @{$Input}; $j++) {
			if ($Input->[$j] =~ m/Answer:/) {
				push(@{$CombinedOutput},$Input->[$j+1]);
			}
		}
	} else {
		my $Input = LoadSingleColumnFile($Script,"");
		my $NewFilename = substr($Script,0,length($Script)-4).$i.".txt";
		$Input->[0] = "set.seed(".(8743+2137*$i).")";
		PrintArrayToFile($NewFilename,$Input);
		#system("qsub -l arch=lx26-amd64 -b yes /home/chenry/Software/R-2.9.0/bin/R --save <".$NewFilename." >".$i.".txt");
	}
}

if ($Script eq "COMBINE") {
	PrintArrayToFile($Outputpath."CombinedResult.txt",$CombinedOutput);
}
