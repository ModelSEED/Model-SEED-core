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
    "h|help" => \$args->{"help"},
    "man" => \$args->{"man"},
);

pod2usage(1) if $args->{"help"};
pod2usage(-exitstatus => 0, -verbose => 2) if $args->{"man"};
pod2usage(1) if (!defined($args->{"-p"}));

my $os = 'linux';
# figure out OS from $^O variable for extension, arguments and delim:
if($^O =~ /cygwin/ || $^O =~ /MSWin32/) {
    $os = 'windows';
} elsif($^O =~ /darwin/) {
    $os = 'osx';
}

# Setting paths to absolute, otherwise a path like ../../foo/bar would cause massive issues...
$args->{"-p"} = abs_path($args->{"-p"}).'/';

#If the OS is windows, we copy the precompiled binaries into the bin directory
if ($os eq "windows") {
	File::Copy::copy($args->{"-p"}."software/mfatoolkit/Windows/SystemParameters.txt",$args->{"-p"}."software/mfatoolkit/bin/SystemParameters.txt");
	File::Copy::copy($args->{"-p"}."software/mfatoolkit/Windows/MFAToolkitCPLEX.exe",$args->{"-p"}."software/mfatoolkit/bin/mfatoolkit.exe");
	chmod 0775,$args->{"-p"}."software/mfatoolkit/bin/mfatoolkit.exe";
} else {
	#Running make
	File::Copy::copy($args->{"-p"}."software/mfatoolkit/Linux/makeMFAToolkit.sh",$args->{"-p"}."software/mfatoolkit/bin/makeMFAToolkit.sh");
	chmod 0775,$args->{"-p"}."/software/mfatoolkit/bin/makeMFAToolkit.sh";
	my $makeCommand = $args->{"-p"}."software/mfatoolkit/bin/makeMFAToolkit.sh";
	if (defined($args->{"-clean"})) {
		$makeCommand .= " clean"; 
	}
	system($makeCommand);
	#Copying executable and parameter files
	File::Copy::copy($args->{"-p"}."software/mfatoolkit/Linux/mfatoolkit",$args->{"-p"}."software/mfatoolkit/bin/mfatoolkit");
	File::Copy::copy($args->{"-p"}."software/mfatoolkit/Linux/SystemParameters.txt",$args->{"-p"}."software/mfatoolkit/bin/SystemParameters.txt");
	chmod 0775,$args->{"-p"}."software/mfatoolkit/bin/mfatoolkit";
}

1;

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

=cut
