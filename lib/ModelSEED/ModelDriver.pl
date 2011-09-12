#!/usr/bin/perl -w

########################################################################
# Driver script that governs user interaction with the Model SEED
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 9/6/2011
########################################################################

use strict;
use ModelSEED::ModelDriver;

$|=1;

#First checking to see if at least one argument has been provided
if (!defined($ARGV[0]) || $ARGV[0] eq "help") {
    print "Function name must be specified as input arguments!\n";;
	exit(0);
}

#This variable will hold the name of a file that will be printed when a job finishes
my $Status = "SUCCESS";

#Searching for recognized arguments
my $driv = ModelSEED::ModelDriver->new();
for (my $i=0; $i < @ARGV; $i++) {
    $ARGV[$i] =~ s/___/ /g;
    $ARGV[$i] =~ s/\.\.\./(/g;
    $ARGV[$i] =~ s/,,,/)/g;
    print "\nProcessing argument: ".$ARGV[$i]."\n";
    if ($ARGV[$i] =~ m/^finish\?(.+)/) {
        $driv->{_finishedfile} = $1;
    } elsif ($ARGV[$i] =~ m/\^finish$/ && defined($ARGV[$i+1])) {
    	$driv->{_finishedfile} = $ARGV[$i+1];
    	$i++;
    } elsif ($ARGV[$i] =~ m/^usage\?(.+)/) {
    	$driv->usage($1);
    } elsif ($ARGV[$i] =~ m/^usage$/ && defined($ARGV[$i+1])) {
    	$driv->usage($ARGV[$i+1]);
    	$i++;
	} else {
        #Splitting argument
        my @Data = split(/\?/,$ARGV[$i]);
        my $FunctionName = $Data[0];
		if (@Data == 1) {
			my $args = {};
			while (defined($ARGV[$i+2]) && $ARGV[$i+1] =~ m/^\-(.+)/) {
				$args->{$1} = $ARGV[$i+2];
				$i = $i+2;
			}
			@Data = ($FunctionName,$args);
		} else {
			for (my $j=0; $j < @Data; $j++) {
				if (length($Data[$j]) == 0) {
					delete $Data[$j];
				}
			}
		}
        #Calling function
        $Status .= $driv->$FunctionName(@Data);
    }
}
#Printing the finish file if specified
$driv->finish($Status);

1;
