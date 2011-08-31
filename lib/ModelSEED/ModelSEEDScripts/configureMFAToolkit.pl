#!/usr/bin/perl -w
########################################################################
# This perl script configures the MFAToolkit installation in the MOdel SEED
# Author: Christopher Henry
# Author email: chrisshenry@gmail.com
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of script creation: 8/30/2011
########################################################################
use strict;
use Getopt::Long;
use Pod::Usage;
use File::Copy;
use Cwd qw(abs_path);

my $args = {};
my $result = GetOptions(
    "p|installation_directory=s" => \$args->{"-p"},
    "d|data_directory=s" => \$args->{"-d"},
    "glpk|glpk_location=s" => \$args->{"-glpk"},
    "cplex|cplex_location=s" => \$args->{"-cplex"},
    "os|operating_system=s" => \$args->{"-os"},
    "h|help" => \$args->{"help"},
    "man" => \$args->{"man"},
) || pod2usage(2);

pod2usage(1) if $args->{"help"};
pod2usage(-exitstatus => 0, -verbose => 2) if $args->{"man"};
pod2usage(1) unless(defined($args->{"-p"}) && defined($args->{"-d"}));

my $extension = ".sh";
if (defined($args->{"-os"}) && $args->{"-os"} eq "windows") {
    $extension = ".bat";
}
# Setting paths to absolute, otherwise a path like ../../foo/bar would cause massive issues...
$args->{"-p"} = abs_path($args->{"-p"}).'/';
$args->{"-d"} = abs_path($args->{"-d"}).'/';
$args->{"-cplex"} = abs_path($args->{"-cplex"}) if(defined($args->{"-cplex"}));
$args->{"-glpk"} = abs_path($args->{"-cplex"}) if(defined($args->{"-glpk"}));

$args->{"-figconfig"} = abs_path($args->{"-figconfig"}) if(defined($args->{"-figconfig"}));

warn $args->{"-p"}."\n";

#If the OS is windows, we copy the precompiled binaries into the bin directory
if (defined($args->{"-os"}) && $args->{"-os"} eq "windows") {
	File::Copy::copy($args->{"-p"}."software/mfatoolkit/Windows/SystemParameters.txt",$args->{"-p"}."software/mfatoolkit/bin/SystemParameters.txt");
	if (defined($args->{"-cplex"})) {
		File::Copy::copy($args->{"-p"}."software/mfatoolkit/Windows/MFAToolkitCPLEX.exe",$args->{"-p"}."software/mfatoolkit/bin/mfatoolkit.exe");
	} else {
		File::Copy::copy($args->{"-p"}."software/mfatoolkit/Windows/MFAToolkitNoCPLEX.exe",$args->{"-p"}."software/mfatoolkit/bin/mfatoolkit.exe");
	}
} else {
	#Running make
	my $makeCommand = $args->{"-p"}."software/mfatoolkit/Linux/make.sh \"".$args->{"-p"}."software/mfatoolkit/Linux/\" \"".$args->{"-glpk"}."\"";
	if (defined($args->{"-cplex"})) {
		$makeCommand .= " \"".$args->{"-cplex"}."\"";
		File::Copy::copy($args->{"-p"}."software/mfatoolkit/Linux/makefilecplex",$args->{"-p"}."software/mfatoolkit/Linux/makefile");
	} else {
		$makeCommand .= " nocplex";
		File::Copy::copy($args->{"-p"}."software/mfatoolkit/Linux/makefilenocplex",$args->{"-p"}."software/mfatoolkit/Linux/makefile");
	}
	if (defined($args->{"-clean"})) {
		$makeCommand .= " clean"; 
	} else {
		$makeCommand .= " noclean";
	}
	system($makeCommand);
	#Copying executable and parameter files
	File::Copy::copy($args->{"-p"}."software/mfatoolkit/Linux/mfatoolkit",$args->{"-p"}."software/mfatoolkit/bin/mfatoolkit");
	File::Copy::copy($args->{"-p"}."software/mfatoolkit/Linux/SystemParameters.txt",$args->{"-p"}."software/mfatoolkit/bin/SystemParameters.txt");
}

$|=1; # ??

__DATA__

=head1 NAME

configureMFAToolkit - configures and makes the MFAToolkit, an essential portion of the Model SEED

=head1 SYNOPSIS

configureMFAToolkit [options]

Options:

    --help                          brief help message
    -h
    -?
    --man                           returns this documentation
*   --installation_directory [-p]   location of ModelSEED installation directory (required)
    --glpk                          location of GLPK installation (required)
    --cplex                         location of CPLEX installation (optional)
    --os                            operating system, "windows", "osx" or "linux" (optional)

=cut
