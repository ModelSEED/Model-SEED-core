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
use Try::Tiny;
use File::Temp;
use Cwd;

$|=1;
#First checking to see if at least one argument has been provided
my $driv;
try {
	$driv = ModelSEED::ModelDriver->new();
} catch {
	printErrorLog($_);
    exit(1);
};
if (!defined($ARGV[0]) || $ARGV[0] eq "help" || $ARGV[0] eq "-man" || $ARGV[0] eq "-help") {
    print "Welcome to the Model SEED! You are currently logged in as: ".ModelSEED::Interface::interface::USERNAME().".\n";
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

#Searching for recognized arguments
for (my $i=0; $i < @ARGV; $i++) {
	$ARGV[$i] =~ s/\x{d}//g;#Cleaning out some weird characters Cygwin sometimes adds to input
}
for (my $i=0; $i < @ARGV; $i++) {
    $ARGV[$i] =~ s/___/ /g;
    $ARGV[$i] =~ s/\.\.\./(/g;
    $ARGV[$i] =~ s/,,,/)/g;
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
        $FunctionName =~ s/\-//g;
		if (@Data == 1) {
			if (defined($ARGV[$i+1]) && $ARGV[$i+1] =~ m/\?/) {
				push(@Data,split(/\?/,$ARGV[$i+1]));
				for (my $j=0; $j < @Data; $j++) {
					if (length($Data[$j]) == 0) {
						delete $Data[$j];
					}
				}
				$i++;
			} else {
				my $args = {};
				while (defined($ARGV[$i+2]) && $ARGV[$i+1] =~ m/^\-(.+)/) {
					$args->{$1} = $ARGV[$i+2];
					$i = $i+2;
				}
				@Data = ($FunctionName,$args);
			}
		} else {
			for (my $j=0; $j < @Data; $j++) {
				if (length($Data[$j]) == 0) {
					delete $Data[$j];
				}
			}
		}
        #Calling function
        try {
            $Status .= $driv->$FunctionName(@Data);
            print $Status."\n";
        } catch {
            printErrorLog($_);
        };
    }
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
A complete log of the problem has been printed to:

$errorFilename

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
