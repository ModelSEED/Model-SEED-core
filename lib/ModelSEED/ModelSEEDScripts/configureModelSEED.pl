#!/usr/bin/perl -w
########################################################################
# This perl script configures a model seed installation
# Author: Christopher Henry
# Author email: chrisshenry@gmail.com
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of script creation: 8/29/2011
########################################################################
use strict;
use Getopt::Long;
use Pod::Usage;
use Cwd qw(abs_path);
use File::Path qw(make_path);
use Data::Dumper;

my $args = {};
my $result = GetOptions(
    "s|settings=s" => \$args->{"-settings"},
    "f|figconfig=s" => \$args->{"-figconfig"},
    "h|help" => \$args->{"help"},
    "man" => \$args->{"man"},
);
pod2usage(1) if $args->{"help"};
pod2usage(-exitstatus => 0, -verbose => 2) if $args->{"man"};
#Setting default values for settings
if (!defined($args->{"-settings"})) {
	$args->{"-settings"} = "../config/Settings.txt";
}
$args->{"-settings"} = abs_path($args->{"-settings"});
#Loading settings file
if (!-e $args->{"-settings"}) {
	print STDERR "Cannot find settings file:".$args->{"-settings"}."\n";
}
my $data = loadFile($args->{"-settings"});
for (my $i=0; $i < @{$data}; $i++) {
	if ($data->[$i] =~ m/^([^:]+):\t*([^\t]+)/) {
		$args->{$1} = $2;
	}
}
# Setting paths to absolute, otherwise a path like ../../foo/bar would cause massive issues...
$args->{"Installation path"} = abs_path($args->{"Installation path"}).'/';
$args->{"Data directory"} = abs_path($args->{"Data directory"}).'/';
my $optionalVariables = ["GLPK directory","CPLEX include directory","CPLEX library directory","CPLEX license directory","Database password"];
for (my $i=0; $i < @{$optionalVariables}; $i++) {
	if (defined($args->{$optionalVariables->[$i]}) && (uc($args->{$optionalVariables->[$i]}) eq "NONE" || $args->{$optionalVariables->[$i]} eq "")) {
		delete $args->{$optionalVariables->[$i]};
	}
}
$args->{"GLPK directory"} = abs_path($args->{"GLPK directory"}).'/' if(defined($args->{"GLPK directory"}));
$args->{"CPLEX include directory"} = abs_path($args->{"CPLEX include directory"}).'/' if(defined($args->{"CPLEX include directory"}));
$args->{"CPLEX library directory"} = abs_path($args->{"CPLEX library directory"}).'/' if(defined($args->{"CPLEX library directory"}));
$args->{"CPLEX license directory"} = abs_path($args->{"CPLEX license directory"}).'/' if(defined($args->{"CPLEX license directory"}));
$args->{"-figconfig"} = abs_path($args->{"-figconfig"}) if(defined($args->{"-figconfig"}));
my $extension = ".sh";
my $arguments = "\$*";
my $delim = ":";
if (defined($args->{"Operating system"}) && lc($args->{"Operating system"}) eq "windows") {
	$arguments = "%*";
	$extension = ".cmd";
	$delim = ";";
}
#Creating missing directories
{
	my $directories = [
		"bin",
		"config",
		"data",
		"lib",
		"logs",
		"software"	
	];
	for (my $i=0; $i < @{$directories}; $i++) {
		if (!-d $args->{"Installation path"}.$directories->[$i]) {
			File::Path::mkpath $args->{"Installation path"}.$directories->[$i];
		}
	}
	
}
#Creating config/FIGMODELConfig.txt
{
    my $data = loadFile($args->{"Installation path"}."lib/ModelSEED/FIGMODELConfig.txt");
    for (my $i=0; $i < @{$data}; $i++) { 
        if ($data->[$i] =~ m/^database\sroot\sdirectory/) {
            $data->[$i] = "database root directory|".$args->{"Data directory"};
        } elsif ($data->[$i] =~ m/^software\sroot\sdirectory/) {
            $data->[$i] = "software root directory|".$args->{"Installation path"};
        } elsif ($data->[$i] =~ m/mfatoolkit\/bin\/mfatoolkit/ && defined($args->{"Operating system"}) && lc($args->{"Operating system"}) eq "windows") {
            $data->[$i] = $data->[$i].".exe";
        }
    }
	printFile($args->{"Installation path"}."config/FIGMODELConfig.txt",$data);
}
#Creating config/ModelSEEDbootstrap.pm
{
    my $data = [
    	"use lib '".$args->{"Installation path"}."lib/PPO';",
    	"use lib '".$args->{"Installation path"}."lib/myRAST';",
    	"use lib '".$args->{"Installation path"}."lib/FigKernelPackages';",
    	"use lib '".$args->{"Installation path"}."lib';"
	];
	if (defined($args->{"CPLEX include directory"})) {
		push(@{$data},'$ENV{CPLEXINCLUDE}=\''.$args->{"CPLEX include directory"}.'\';');
		push(@{$data},'$ENV{CPLEXLIB}=\''.$args->{"CPLEX library directory"}.'\';');
		push(@{$data},'$ENV{ILOG_LICENSE_FILE}=\''.$args->{"CPLEX license directory"}.'\';');
	}
	if (defined($args->{"GLPK directory"})) {
		push(@{$data},'$ENV{GLPKDIRECTORY}=\''.$args->{"GLPK directory"}.'\';');
	}
	push(@{$data},'$ENV{PATH}=\''.$args->{"Installation path"}.'bin/'.$delim.$args->{"Installation path"}.'lib/ModelSEED/ModelSEEDScripts/'.$delim.$ENV{PATH}.'\';');
	if (defined($args->{"SEED username"}) && defined($args->{"SEED password"})) {
	    push(@{$data},'$ENV{FIGMODEL_USER}=\''.$args->{"SEED username"}.'\';');
	    push(@{$data},'$ENV{FIGMODEL_PASSWORD}=\''.$args->{"SEED password"}.'\';');
	}
	my $configFiles = $args->{"Installation path"}."config/FIGMODELConfig.txt";
	if (defined($args->{"-figconfig"})) {
	    $configFiles .= ";".$args->{"-figconfig"};
	}
	push(@{$data},'$ENV{FIGMODEL_CONFIG}=\''.$configFiles.'\';');
	push(@{$data},'$ENV{ARGONNEDB}=\''.$args->{"Data directory"}.'ReactionDB/\';');
	push(@{$data},'if (defined($ARGV[0])) {');
	push(@{$data},'	my $prog = shift(@ARGV);');
	push(@{$data},'	if ($prog =~ /ModelDriver\.pl/ && $ARGV[0] =~ m/FUNCTION:(.+)/) {');
	push(@{$data},'		my $function = $1;');
	push(@{$data},'		if (defined($ARGV[1]) && ($ARGV[1] eq "-usage" || $ARGV[1] eq "-h" || $ARGV[1] eq "-help")) {');
	push(@{$data},'			@ARGV = ("usage?".$function);');
	push(@{$data},'		} else {');
	push(@{$data},'			$ARGV[0] = $function;');
	push(@{$data},'		}');
	push(@{$data},'	}');
	push(@{$data},'	do $prog;');
	push(@{$data},'	if ($@) { die "Failure running $prog: $@\n"; }');
	push(@{$data},'}');
	push(@{$data},'1;');
    printFile($args->{"Installation path"}."config/ModelSEEDbootstrap.pm",$data);
}
#Creating shell scripts for individual perl scripts
{
	my $mfatoolkitScript = "lib/ModelSEED/ModelSEEDScripts/configureMFAToolkit.pl\" -p \"".$args->{"Installation path"};
	if (defined($args->{"CPLEX include directory"})) {
		$mfatoolkitScript .= "\" --cplex \"".$args->{"CPLEX include directory"};	
	}
	if (defined($args->{"Operating system"})) {
		$mfatoolkitScript .= "\" --os \"".$args->{"Operating system"};	
	}
	my $password = "";
	if (defined($args->{"Database password"})) {
		$password = "-password ".$args->{"Database password"}." ";
	}
	my $ppoScript = 'lib/PPO/ppo_generate.pl" -xml '.$args->{"Installation path"}."lib/ModelSEED/ModelDB/ModelDB.xml ".
		"-backend MySQL ".
		"-database ModelDB ".
		"-host ".$args->{"Database host"}." ".
		"-user ".$args->{"Database username"}." ".
		$password.
		'-port "3306';
	my $plFileList = {
		"lib/ModelSEED/FIGMODELscheduler.pl" => "QueueDriver",
		"lib/ModelSEED/ModelDriver.pl" => "ModelDriver",
		$ppoScript => "CreateDBScheme",
		$mfatoolkitScript => "makeMFAToolkit",
		"lib/ModelSEED/ModelDriver.pl" => "ModelDriver"
	};
	foreach my $file (keys(%{$plFileList})) {
		if (-e $args->{"Installation path"}."bin/".$plFileList->{$file}.$extension) {
			unlink $args->{"Installation path"}."bin/".$plFileList->{$file}.$extension;	
		}
		my $data = ['perl "'.$args->{"Installation path"}.'config/ModelSEEDbootstrap.pm" "'.$args->{"Installation path"}.$file.'" '.$arguments];
		if (defined($args->{"Operating system"}) && lc($args->{"Operating system"}) eq "windows") {
			my $data = ['@echo off','perl "'.$args->{"Installation path"}.'config/ModelSEEDbootstrap.pm" "'.$args->{"Installation path"}.$file.'" '.$arguments,"pause"];	
		}
		printFile($args->{"Installation path"}."bin/".$plFileList->{$file}.$extension,$data);
		chmod 0775,$args->{"Installation path"}."bin/".$plFileList->{$file}.$extension;
	}
}
#Creating shell scripts for select model driver functions
{
	my $functionList = [
		"adduser",
		"testmodelgrowth",
		"importmodel"
	];
	foreach my $function (@{$functionList}) {
		if (-e $args->{"Installation path"}."bin/".$function.$extension) {
			unlink $args->{"Installation path"}."bin/".$function.$extension;
		}
		my $data = ['@echo off','perl "'.$args->{"Installation path"}.'config/ModelSEEDbootstrap.pm" "'.$args->{"Installation path"}.'lib/ModelSEED/ModelDriver.pl" "FUNCTION:'.$function.'" '.$arguments,"pause"];
		printFile($args->{"Installation path"}."bin/".$function.$extension,$data);
		chmod 0775,$args->{"Installation path"}."bin/".$function.$extension;
	}
}
#Configuring database
{
	$args->{"Database host"} = "" unless(defined($args->{"Database host"}));
	$args->{"Database username"} = "" unless(defined($args->{"Database username"}));
	$args->{"Database password"} = "" unless(defined($args->{"Database password"}));
	my $data = loadFile($args->{"Installation path"}."config/FIGMODELConfig.txt");
	my $dbList = ["ModelDB","SchedulerDB"];
	for (my $j=0; $j < @{$dbList}; $j++) {
		for (my $i=0; $i < @{$data}; $i++) {
			if ($data->[$i] =~ m/^%PPO_tbl_(\w+)\|.*name;(\w+)\|.*table;(\w+)\|/) {
				if ($2 eq $dbList->[$j]) {
					my $password = "";
					if (defined($args->{"Database password"}) && $args->{"Database password"} ne "") {
						$password = "password;".$args->{"Database password"}."|";
					}
					$data->[$i] = "%PPO_tbl_".$1."|"
						."name;".$dbList->[$j]."|"
						."table;".$3."|"
						."host;".$args->{"Database host"}."|"
						."user;".$args->{"Database username"}."|"
						.$password
						."port;3306|"
						."socket;/var/lib/mysql/mysql.sock|"
						."status;1|"
						."type;PPO";
				}
			}
		}
	}
	printFile($args->{"Installation path"}."config/FIGMODELConfig.txt",$data);
}
#Configuring MFAToolkit
{	
	if (lc($args->{"Operating system"}) ne "windows") {
		my $data = ['cd "'.$args->{"Installation path"}.'software/mfatoolkit/Linux/"'];
		push(@{$data},'if [ "$1" == "clean" ]');
		push(@{$data},'    then make clean');
		push(@{$data},'fi');
		push(@{$data},'make');
		printFile($args->{"Installation path"}."software/mfatoolkit/bin/makeMFAToolkit.sh",$data);
		chmod 0775,$args->{"Installation path"}."software/mfatoolkit/bin/makeMFAToolkit.sh";
	}
	system($args->{"Installation path"}."bin/makeMFAToolkit".$extension);
}
1;
#Utility functions used by the configuration script
sub printFile {
    my ($filename,$arrayRef) = @_;
    open ( my $fh, ">", $filename) || die("Failure to open file: $filename, $!");
    foreach my $Item (@{$arrayRef}) {
        if (length($Item) > 0) {
            print $fh $Item."\n";
        }
    }
    close($fh);
}

sub loadFile {
    my ($Filename) = @_;
    my $DataArrayRef = [];
    if (open (INPUT, "<", $Filename)) {
        while (my $Line = <INPUT>) {
            chomp($Line);
            push(@{$DataArrayRef},$Line);
        }
        close(INPUT);
    }
    return $DataArrayRef;
}

__DATA__

=head1 NAME

configureModelSEED - configures the Model SEED installation

=head1 SYNOPSIS

configureModelSEED [options]

Options:

    --help [-h]                     brief help message
    --man                           returns this documentation
    
    --username [--usr]               
    --figconfig [-f]                name of additional figconfig to be loaded
    --settings [-s]                 name of file with Model SEED settings (../config/Settings.txt)
    
=cut
