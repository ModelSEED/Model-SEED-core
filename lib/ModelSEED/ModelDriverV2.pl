#!/usr/bin/perl -w

########################################################################
# Driver script that governs user interaction with the Model SEED
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 9/6/2011
########################################################################
use strict;
use ModelSEED::ModelDriverV2;
use Try::Tiny;
use File::Temp;
use Cwd;

$|=1;
#First checking to see if at least one argument has been provided
my $driv;
try {
	$driv = ModelSEED::ModelDriverV2->new({});
} catch {
	printErrorLog($_);
    exit(1);
};
if (!defined($ARGV[0]) || $ARGV[0] eq "help" || $ARGV[0] eq "-man" || $ARGV[0] eq "-help") {
    print "Welcome to the Model SEED! You are currently logged in as: ".$driv->environment()->username().".\n";
    print "ModelDriver is the primary executable for the Model SEED.\n\n";
    print "Possible usage:\n\n";
    print "1.) ModelDriver usage \"name of function\"\n";
    print "Prints the arguments list expected by the function\n\n";
    print "2.) ModelDriver \"name of function\" \"-argument name\" \"argument value\" \"-argument name\" \"argument value\"\n";
    print "This is the standard notation, useful to know exactly what arguments you're submitting, but it's also alot of typing.\n\n";
    print "3.) ModelDriver \"name of function?argument value?argument value\"\n";
    print "This is the alternative notation. Argument values are input directly in the same order specified by the \"usage\" command.\n";
	exit(0);
}

#This variable will hold the name of a file that will be printed when a job finishes
my $Status = "";
#Cleaning out some weird characters Cygwin sometimes adds to input
for (my $i=0; $i < @ARGV; $i++) {
	$ARGV[$i] =~ s/\x{d}//g;
}
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
		if (defined($lastKeyType) && $lastKeyType eq "argHash") {
			$currentFunction->{argHash}->{$lastKey} .= " ".$ARGV[$i];
		}  elsif (defined($lastKeyType) && $lastKeyType eq "argList") {
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
	print $function."\n";
	my @Data = ($function);
	if (keys(%{$functions->[$i]->{argHash}}) > 0) {
		push(@Data,$functions->[$i]->{argHash});
	} else {
		push(@Data,@{$functions->[$i]->{argList}});
	}
	try {
    	my $driverOutput = $driv->$function(@Data);
    	print $driverOutput->{message}."\n\n";
   	} catch {
        printErrorLog($_);
    };
}
#Printing the finish file if specified
$driv->finish($Status);

sub printErrorLog {
    my $errorMessage = shift @_;
    my $actualMessage;
    if($errorMessage =~ /^\"\"(.*)\"\"/) {
        $actualMessage = $1;
    }
    {
        # Pad error message with four spaces
        $errorMessage =~ s/\n/\n    /g;
        $errorMessage = "    ".$errorMessage; 
    }
    my $gitSha = "";
    {
        my $cwd = Cwd::getcwd();
        chdir $ENV{'MODEL_SEED_CORE'};
        $gitSha = `git show-ref --hash HEAD`;
        chdir $cwd;
    }
    
    chomp $gitSha;
    my $errorDir= $ENV{'MODEL_SEED_CORE'}."/.errors/";
    mkdir $errorDir unless(-d $errorDir);
    my ($errorFH, $errorFilename) = File::Temp::tempfile("error-XXXXX", DIR => $errorDir);
    $errorFilename =~ s/\\/\//g;
    $driv->environment()->lasterror($errorFilename);
    $driv->environment()->save();
    print $errorFH <<MSG;
> ModelDriver encountered an unrecoverable error:

$errorMessage

> Model-SEED-core revision: $gitSha
MSG
    my $viewerMessage = <<MSG;
Whoops! We encountered an unrecoverable error.

MSG
    if(defined($actualMessage)) {
        $viewerMessage .= $actualMessage."\n\n";
    }
    $viewerMessage .= <<MSG;

View error using the "ms-lasterror" command.

Have you updated recently? ( git pull )
Have you changed your configuration? ( ms-config )

If you are still having problems, please submit a ticket
copying the contents of the error file printed above to:

https://github.com/ModelSEED/Model-SEED-core/issues/new

Thanks!
MSG
    print $viewerMessage;
}

1;
