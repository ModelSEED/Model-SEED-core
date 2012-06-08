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
use ModelSEED::Interface::interface;
use Try::Tiny;
use File::Temp;
use Cwd;
$|=1;
my $JOBDIR =  "/vol/model-prod/jobfiles/";
if (defined($ENV{"MSJOBDIR"})) {
	$JOBDIR = $ENV{"MSJOBDIR"};
}
#Creating temporary environment file
my ($fh, $filename) = File::Temp::tempfile(
	"environment-XXXXXX",
	DIR => $JOBDIR."/environments/");
close($fh);
ModelSEED::Interface::interface::ENVIRONMENTFILE($filename);
#Cleaning out some weird characters Cygwin sometimes adds to input
for (my $i=0; $i < @ARGV; $i++) {
	$ARGV[$i] =~ s/\x{d}//g;
}
#Setting environment from commandline
for (my $i=0; $i < @ARGV; $i++) {
	if ($ARGV[$i] =~ m/^environment\?/) {
		my $array = [split(/\?/,$ARGV[$i])];
		ModelSEED::Interface::interface::USERNAME($array->[1]);
		ModelSEED::Interface::interface::PASSWORD($array->[2]);
		ModelSEED::Interface::interface::REGISTEREDSEED($array->[3]);
		ModelSEED::Interface::interface::SEED($array->[4]);
		ModelSEED::Interface::interface::LASTERROR($array->[5]);
		splice(@ARGV,$i,1);
	}	
}
if (!defined($ARGV[0])) {
	exit(0);
}
#Creating model driver object
my $driv = ModelSEED::ModelDriver->new();
#This variable will hold the name of a file that will be printed when a job finishes
my $Status = "";
#Parsing arguments into a list of function calls
my $currentFunction;
my $functions;
my $lastKey;
my $lastKeyType;
my $prefixes = ["ms","mdl","db","bc","fba","gen","sq"];
for (my $i=0; $i < @ARGV; $i++) {
	for (my $j=0; $j < @{$prefixes}; $j++) {
		my $search = "^".$prefixes->[$j]."-";
		my $prefix = $prefixes->[$j];
		$ARGV[$i] =~ s/$search/$prefix/g;
	}
	$ARGV[$i] =~ s/___/ /g;
    $ARGV[$i] =~ s/\.\.\./(/g;
    $ARGV[$i] =~ s/,,,/)/g;
	if ($ARGV[$i] =~ m/^finish\?(.+)/) {
		$driv->finishfile($1);
	} elsif ($ARGV[$i] =~ m/\?/) {
		my $subarray = [split(/\?/,$ARGV[$i])];
		if (length($subarray->[0]) > 0) {
			if ($driv->isCommandLineFunction($subarray->[0]) == 1) {
				if (defined($currentFunction)) {
					push(@{$functions},$currentFunction);
				}
				$currentFunction = {
					name => shift(@{$subarray}),
					argHash => {},
					argList => []	
				};
			}
		}
		push(@{$currentFunction->{argList}},@{$subarray});
		$lastKey = @{$currentFunction->{argList}}-1;
		$lastKeyType = "argList";
    } elsif ($ARGV[$i] =~ m/\^finish$/ && defined($ARGV[$i+1])) {
    	$driv->finishfile($ARGV[$i+1]);
    	$i++;
    } elsif ($ARGV[$i] =~ m/^usage\?(.+)/) {
    	my $function = $1;
    	$driv->usage($function);
    } elsif ($ARGV[$i] =~ m/^usage$/ && defined($ARGV[$i+1])) {
    	$driv->usage($ARGV[$i+1]);
    	$i++;
    } elsif ($ARGV[$i] =~ m/^-usage$/ || $ARGV[$i] =~ m/^-help$/ ||  $ARGV[$i] =~ m/^-man$/) {
    	if (defined($currentFunction->{name})) {
    		$driv->usage($currentFunction->{name});
    	}
    	$i++;
	} elsif ($ARGV[$i] =~ m/^\-(.+)/) {
		$lastKey = $1;
		$lastKeyType = "argHash";
		$currentFunction->{argHash}->{$lastKey} = $ARGV[$i+1];
		$i++;
	} elsif ($driv->isCommandLineFunction($ARGV[$i]) == 1) {
		if (defined($currentFunction)) {
			push(@{$functions},$currentFunction);
		}
		$currentFunction = {
			name => $ARGV[$i],
			argHash => {},
			argList => []	
		};
	} else {
		if ($lastKeyType eq "argHash") {
			$currentFunction->{argHash}->{$lastKey} .= " ".$ARGV[$i];
		}  elsif ($lastKeyType eq "argList") {
			$currentFunction->{argList}->[$lastKey] .= " ".$ARGV[$i];
		} else {
			push(@{$currentFunction->{argList}},$ARGV[$i]);	
		}
	}
}
if (defined($currentFunction)) {
	push(@{$functions},$currentFunction);
}
#Calling functions
for (my $i=0; $i < @{$functions}; $i++) {
	my $function = $functions->[$i]->{name};
	my @Data = ($function);
	if (keys(%{$functions->[$i]->{argHash}}) > 0) {
		push(@Data,$functions->[$i]->{argHash});
	} else {
		push(@Data,@{$functions->[$i]->{argList}});
	}
    $Status .= $driv->$function(@Data);
    print $Status."\n";
}
#Printing the finish file if specified
$driv->finish($Status);

1;
