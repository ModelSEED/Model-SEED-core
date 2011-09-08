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
use File::Path;

my $args = {};
my $result = GetOptions(
    "p|installation_directory=s" => \$args->{"-p"},
    "d|data_directory=s" => \$args->{"-d"},
    "g|glpk=s" => \$args->{"-glpk"},
    "cl|cplex_licence=s" => \$args->{"-licence"},
    "c|cplex=s" => \$args->{"-cplex"},
    "os|operating_system=s" => \$args->{"-os"},
    "usr|username=s" => \$args->{"-usr"},
    "pwd|password=s" => \$args->{"-pwd"},
    "figconfig=s" => \$args->{"-figconfig"},
    "dbhost=s" => \$args->{"-dbhost"},
    "dbuser=s" => \$args->{"-dbusr"},
    "dbpwd=s" => \$args->{"-dbpwd"},
    "h|help" => \$args->{"help"},
    "man" => \$args->{"man"},
);

pod2usage(1) if $args->{"help"};
pod2usage(-exitstatus => 0, -verbose => 2) if $args->{"man"};
pod2usage(1) if(!defined($args->{"-p"}) || !defined($args->{"-d"}));

# Setting paths to absolute, otherwise a path like ../../foo/bar would cause massive issues...
$args->{"-p"} = abs_path($args->{"-p"}).'/';
$args->{"-d"} = abs_path($args->{"-d"}).'/';
$args->{"-glpk"} = abs_path($args->{"-glpk"}) if(defined($args->{"-glpk"}));
$args->{"-cplex"} = abs_path($args->{"-cplex"}) if(defined($args->{"-cplex"}));
$args->{"-figconfig"} = abs_path($args->{"-figconfig"}) if(defined($args->{"-figconfig"}));
my $extension = ".sh";
my $delim = ":";
if (defined($args->{-os}) && $args->{-os} eq "windows") {
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
		if (!-d $args->{-p}.$directories->[$i]) {
			File::Path::mkpath $args->{-p}.$directories->[$i];
		}
	}
	
}
#Creating config/FIGMODELConfig.txt
{
    my $data = loadFile($args->{"-p"}."lib/ModelSEED/FIGMODELConfig.txt");
    for (my $i=0; $i < @{$data}; $i++) { 
        if ($data->[$i] =~ m/^database\sroot\sdirectory/) {
            $data->[$i] = "database root directory|".$args->{"-d"};
        } elsif ($data->[$i] =~ m/^software\sroot\sdirectory/) {
            $data->[$i] = "software root directory|".$args->{"-p"};
        } elsif ($data->[$i] =~ m/mfatoolkit\/bin\/mfatoolkit/ && defined($args->{"-os"}) && $args->{"-os"} eq "windows") {
            $data->[$i] = $data->[$i].".exe";
        }
    }
	printFile($args->{"-p"}."config/FIGMODELConfig.txt",$data);
}
#Creating config/ModelSEEDbootstrap.pm
{
    my $data = [
    	"use lib '".$args->{-p}."lib/PPO';",
    	"use lib '".$args->{-p}."lib/myRAST';",
    	"use lib '".$args->{-p}."lib/FigKernelPackages';",
    	"use lib '".$args->{-p}."lib';"
	];
	if (defined($args->{"-licence"})) {
		push(@{$data},'$ENV{ILOG_LICENSE_FILE}=\''.$args->{"-licence"}.'\';');
	}
	push(@{$data},'$ENV{PATH}=\''.$args->{-p}.'bin/'.$delim.$args->{-p}.'lib/ModelSEED/ModelSEEDScripts/'.$delim.$ENV{PATH}.'\';');
	if (defined($args->{"-usr"}) && defined($args->{"-pwd"})) {
	    push(@{$data},'$ENV{FIGMODEL_USER}=\''.$args->{"-usr"}.'\';');
	    push(@{$data},'$ENV{FIGMODEL_PASSWORD}=\''.$args->{"-pwd"}.'\';');
	}
	my $configFiles = $args->{"-p"}."config/FIGMODELConfig.txt";
	if (defined($args->{"-figconfig"})) {
	    $configFiles .= ";".join(";",@{$args->{"-figconfig"}});
	}
	push(@{$data},'$ENV{FIGMODEL_CONFIG}=\''.$configFiles.'\';');
	push(@{$data},'$ENV{ARGONNEDB}=\''.$args->{"-d"}.'ReactionDB/\';');
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
    printFile($args->{"-p"}."config/ModelSEEDbootstrap.pm",$data);
}
#Creating shell scripts for individual perl scripts
{
	my $mfatoolkitScript = "lib/ModelSEED/ModelSEEDScripts/configureMFAToolkit.pl -p ".$args->{"-p"};
	if (defined($args->{"-cplex"})) {
		$mfatoolkitScript .= " --cplex ".$args->{"-cplex"};	
	}
	if (defined($args->{"-os"})) {
		$mfatoolkitScript .= " --os ".$args->{"-os"};	
	}
	my $ppoScript = 'lib/PPO/ppo_generate.pl" -xml '.$args->{-p}."lib/ModelSEED/ModelDB/ModelDB.xml ".
		"-backend MySQL ".
		"-database ModelDB2 ".
		"-host ".$args->{"-dbhost"}." ".
		"-user ".$args->{"-dbusr"}." ".
		"-password ".$args->{"-dbpwd"}." ".
		'-port "3306';
	my $plFileList = {
		"lib/ModelSEED/FIGMODELscheduler.pl" => "QueueDriver",
		"lib/ModelSEED/ModelDriver.pl" => "ModelDriver",
		$ppoScript => "CreateDBScheme",
		$mfatoolkitScript => "makeMFAToolkit",
		"lib/ModelSEED/ModelDriver.pl" => "ModelDriver"
	};
	foreach my $file (keys(%{$plFileList})) {
		if (-e $args->{"-p"}."bin/".$plFileList->{$file}.$extension) {
			unlink $args->{"-p"}."bin/".$plFileList->{$file}.$extension;	
		}
		my $data = ['perl "'.$args->{-p}.'config/ModelSEEDbootstrap.pm" "'.$args->{-p}.$file.'" %*'];
		if (defined($args->{"-os"}) && $args->{"-os"} eq "windows") {
			my $data = ['@echo off','perl "'.$args->{-p}.'config/ModelSEEDbootstrap.pm" "'.$args->{-p}.$file.'" %*',"pause"];	
		}
		printFile($args->{"-p"}."bin/".$plFileList->{$file}.$extension,$data);
		chmod 0775,$args->{"-p"}."bin/".$plFileList->{$file}.$extension;
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
		if (-e $args->{"-p"}."bin/".$function.$extension) {
			unlink $args->{"-p"}."bin/".$function.$extension;
		}
		my $data = ['@echo off','perl "'.$args->{-p}.'config/ModelSEEDbootstrap.pm" "'.$args->{-p}.'lib/ModelSEED/ModelDriver.pl" "FUNCTION:'.$function.'" %*',"pause"];
		printFile($args->{"-p"}."bin/".$function.$extension,$data);
		chmod 0775,$args->{"-p"}."bin/".$function.$extension;
	}
}
#Configuring database
{
	$args->{"-dbhost"} = "" unless(defined($args->{"-dbhost"}));
	$args->{"-dbusr"} = "" unless(defined($args->{"-dbusr"}));
	$args->{"-dbpwd"} = "" unless(defined($args->{"-dbpwd"}));
	my $data = loadFile($args->{"-p"}."config/FIGMODELConfig.txt");
	my $dbList = ["ModelDB","SchedulerDB"];
	for (my $j=0; $j < @{$dbList}; $j++) {
		for (my $i=0; $i < @{$data}; $i++) {
			if ($data->[$i] =~ m/^%PPO_tbl_(\w+)\|.*name;(\w+)\|.*table;(\w+)\|/) {
				if ($2 eq $dbList->[$j]) {
					$data->[$i] = "%PPO_tbl_".$1."|"
						."name;".$dbList->[$j]."|"
						."table;".$3."|"
						."host;".$args->{"-dbhost"}."|"
						."user;".$args->{"-dbusr"}."|"
						."password;".$args->{"-dbpwd"}."|"
						."port;3306|"
						."socket;/var/lib/mysql/mysql.sock|"
						."status;1|"
						."type;PPO";
				}
			}
		}
	}
	printFile($args->{"-p"}."config/FIGMODELConfig.txt",$data);
}
#Configuring MFAToolkit
{	
	if ($args->{-os} ne "windows") {
		my $data = [
			'cd "'.$args->{"-p"}.'software/mfatoolkit/Linux/"',
			'export GLPKDIRECTORY="'.$args->{"-glpk"}.'"'
		];
		if (defined($args->{"-cplex"})) {
			push(@{$data},'export CPLEXDIRECTORY="'.$args->{"-cplex"}.'"');
		}
		push(@{$data},'if [ "$1" == "clean" ]');
		push(@{$data},'    then make clean');
		push(@{$data},'fi');
		push(@{$data},'make');
		printFile($args->{"-p"}."software/mfatoolkit/bin/makeMFAToolkit.sh",$data);
		chmod 0775,$args->{"-p"}."software/mfatoolkit/bin/makeMFAToolkit.sh";
	}
	system($args->{"-p"}."bin/makeMFAToolkit".$extension);
}
1;
#Utility functions used by the configuration script
sub printFile {
    my ($filename,$arrayRef) = @_;
    open (OUTPUT, ">$filename");
    foreach my $Item (@{$arrayRef}) {
        if (length($Item) > 0) {
            print OUTPUT $Item."\n";
        }
    }
    close(OUTPUT);
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

configureModelSEED - creates a configuration file for the ModelSEED enviorment

=head1 SYNOPSIS

configureModelSEED [options]

Options:

    --help                          brief help message
    -h
    -?
    --man                           returns this documentation
*   --installation_directory [-p]   location of ModelSEED installation directory
*   --data_directory [-d]           location of ModelSEED data directory
*   --glpk [-g] 			        location of glpk installation directory
    --cplex [-c]                    location of cplex installation directory
    --cplex_licence [-cl]           location of CPLEX licence file
    --os                            operating system, "windows", "osx" or "linux"
    --username [--usr]               
    --figconfig 
    --dbhost
    --dbusr
    --dbpwd 

=cut
