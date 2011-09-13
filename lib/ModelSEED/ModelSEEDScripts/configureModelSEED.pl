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
use Config::Tiny;
use Cwd qw(abs_path);
use File::Path;
# Get the Installation path using what we know about the location
# of this script ( abs_path($0) is absolute path to this script )
my $directoryRoot = abs_path($0);
$directoryRoot =~ s?(.*)/lib/ModelSEED/ModelSEEDScripts/.*?$1?;
my $args = {};
my $result = GetOptions(
    "figconfig|f=s@" => \$args->{"-figconfig"},
    "h|help" => \$args->{"help"},
    "man" => \$args->{"man"},
);
pod2usage(1) if $args->{"help"};
pod2usage(-exitstatus => 0, -verbose => 2) if $args->{"man"};
# Reading the settings file
my $command = shift @ARGV;
unless($command eq "unload" || $command eq "load" || $command eq "reload") {
    pod2usage(2);
}

if($command eq "unload") {
    unload();
    exit();
} elsif($command eq "reload") {
    unload();
}
# By default use config/Settings.config
my $configFile = shift @ARGV || "$directoryRoot/config/Settings.config";
unless(-f $configFile) {
    die("Could not find configuration file at $configFile!");
}
$configFile = abs_path($configFile);
my $Config = Config::Tiny->new();
$Config = Config::Tiny->read($configFile);
# Setting defaults for dataDirectory,
# database (sqlite, data/ModelDB/ModelDB.db), port if db type = mysql
unless(defined($Config->{Optional}->{dataDirectory})) {
    $Config->{Optional}->{dataDirectory} = "$directoryRoot/data";
}
unless(defined($Config->{Database}->{type})) {
    $Config->{Database}->{type} = "sqlite";
}
unless(defined($Config->{Database}->{filename}) ||
        lc($Config->{Database}->{type}) ne 'sqlite') {
    $Config->{Database}->{filename} =
        $Config->{Optional}->{dataDirectory} . "/ModelDB/ModelDB.db";
}
unless(lc($Config->{Database}->{type}) eq 'mysql' &&
    !defined($Config->{Database}->{port})) {
    $Config->{Database}->{port} = "3306";
} 
# Setting paths to absolute for different configuration parameters
foreach my $path ( 
    qw( Optional=dataDirectory Optimizers=directoryGLPK
        Optimizers=libraryDirectoryCPLEX Optimizers=licenseDirectoryCPLEX
        Optimizers=licenseDirectoryCPLEX )) {
    my ($section, $name) = split(/=/, $path);
    if(defined($Config->{$section}->{$name})) {
        $Config->{$section}->{$name} = abs_path($Config->{$section}->{$name});
    }
}
$args->{"-figconfig"} = [ map { $_ = abs_path($_) } @{$args->{"-figconfig"}} ] if(defined($args->{"-figconfig"}));
my $extension = "";
my $arguments = "\$*";
my $delim = ":";
my $os = 'linux';
# figure out OS from $^O variable for extension, arguments and delim:
if($^O =~ /cygwin/ || $^O =~ /MSWin32/) {
    $arguments = "%*";
    $delim = ";";
    $extension = ".cmd";
    $os = 'windows';
} elsif($^O =~ /darwin/) {
    $os = 'osx';
}

#Creating missing directories
{
	my $directories = [qw( bin config data lib logs software )];
    foreach my $dir (@$directories) {
		if (!-d "$directoryRoot/".$dir) {
			File::Path::mkpath "$directoryRoot/".$dir;
		}
	}
}
#Creating config/FIGMODELConfig.txt
{
    my $data = loadFile($directoryRoot."/lib/ModelSEED/FIGMODELConfig.txt");
    for (my $i=0; $i < @{$data}; $i++) { 
        if ($data->[$i] =~ m/^database\sroot\sdirectory/) {
            $data->[$i] = "database root directory|".$Config->{Optional}->{dataDirectory};
        } elsif ($data->[$i] =~ m/^software\sroot\sdirectory/) {
            $data->[$i] = "software root directory|".$directoryRoot;
        } elsif ($data->[$i] =~ m/mfatoolkit\/bin\/mfatoolkit/ && $os eq "windows") {
            $data->[$i] = $data->[$i].".exe";
        }
    }
	printFile($directoryRoot."/config/FIGMODELConfig.txt",$data);
}
#Creating config/ModelSEEDbootstrap.pm
{
    my $data = [
    	"use lib '$directoryRoot/lib/PPO';",
    	"use lib '$directoryRoot/lib/myRAST';",
    	"use lib '$directoryRoot/lib/FigKernelPackages';",
    	"use lib '$directoryRoot/lib';"
	];
	if (defined($Config->{Optimizers}->{includeDirectoryCPLEX})) {
		push(@{$data},'$ENV{CPLEXINCLUDE}=\''.$Config->{Optimizers}->{includeDirectoryCPLEX}.'\';');
		push(@{$data},'$ENV{CPLEXLIB}=\''.$Config->{Optimizers}->{libraryDirectoryCPLEX}.'\';');
		push(@{$data},'$ENV{ILOG_LICENSE_FILE}=\''.$Config->{Optimizers}->{licenceDirectoryCPLEX}.'\';');
	}
	if (defined($Config->{Optimizers}->{directoryGLPK})) {
		push(@{$data},'$ENV{GLPKDIRECTORY}=\''.$Config->{Optimizers}->{directoryGLPK}.'\';');
	}
	push(@{$data},'$ENV{PATH}=\''.$directoryRoot.'/bin/'.$delim.$directoryRoot.'/lib/ModelSEED/ModelSEEDScripts/'.$delim.$ENV{PATH}.'\';');
	if (defined($Config->{Optional}->{username}) && defined($Config->{Optional}->{password})) {
	    push(@{$data},'$ENV{FIGMODEL_USER}=\''.$Config->{Optional}->{username}.'\';');
	    push(@{$data},'$ENV{FIGMODEL_PASSWORD}=\''.$Config->{Optional}->{password}.'\';');
	}
	my $configFiles = $directoryRoot."/config/FIGMODELConfig.txt";
	if (defined($args->{"-figconfig"}) && @{$args->{"-figconfig"}} > 0) {
	    $configFiles .= ";".join(";", @{$args->{"-figconfig"}});
	}
	push(@{$data},'$ENV{FIGMODEL_CONFIG}=\''.$configFiles.'\';');
	push(@{$data},'$ENV{ARGONNEDB}=\''.$Config->{Optional}->{dataDirectory}.'/ReactionDB/\';');
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
    printFile($directoryRoot."/config/ModelSEEDbootstrap.pm",$data);
}
#Creating shell scripts for individual perl scripts
{
	my $mfatoolkitScript = "/lib/ModelSEED/ModelSEEDScripts/configureMFAToolkit.pl\" -p \"".$directoryRoot;
	if (defined($Config->{Optimizers}->{includeDirectoryCPLEX})) {
		$mfatoolkitScript .= "\" --cplex \"".$Config->{Optimizers}->{includeDirectoryCPLEX};	
	}
	if (defined($os)) {
		$mfatoolkitScript .= "\" --os \"".$os;	
	}
	my $password = "";
	if (defined($Config->{Database}->{password})) {
		$password = "-password ".$Config->{Database}->{password}." ";
	}
	my $ppoScript = 'lib/PPO/ppo_generate.pl" -xml '.$directoryRoot.
        "/lib/ModelSEED/ModelDB/ModelDB.xml -backend ".
        $Config->{Database}->{type}." ";
    if(lc($Config->{Database}->{type}) eq 'sqlite') {
        $ppoScript .= "-database ".$Config->{Database}->{filename}; 
    } else {
        $ppoScript .= "-database ModelDB ".
		"-host ".$Config->{Database}->{host}." ".
		"-user ".$Config->{Database}->{username}." ".
		$password . '-port '.$Config->{Database}->{port};
    }
	my $plFileList = {
		"/lib/ModelSEED/FIGMODELscheduler.pl" => "QueueDriver",
		"/lib/ModelSEED/ModelDriver.pl" => "ModelDriver",
		$ppoScript => "CreateDBScheme",
		$mfatoolkitScript => "makeMFAToolkit",
		"/lib/ModelSEED/ModelDriver.pl" => "ModelDriver"
	};
	foreach my $file (keys(%$plFileList)) {
		if (-e $directoryRoot."/bin/".$plFileList->{$file}.$extension) {
			unlink $directoryRoot."/bin/".$plFileList->{$file}.$extension;	
		}
		my $data = ['perl "'.$directoryRoot.'/config/ModelSEEDbootstrap.pm" "'.$directoryRoot.$file.'" '.$arguments];
		if ($os eq "windows") {
			my $data = ['@echo off','perl "'.$directoryRoot.'/config/ModelSEEDbootstrap.pm" "'.$directoryRoot.$file.'" '.$arguments,"pause"];	
		}
		printFile($directoryRoot."/bin/".$plFileList->{$file}.$extension,$data);
		chmod 0775,$directoryRoot."/bin/".$plFileList->{$file}.$extension;
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
		if (-e $directoryRoot."/bin/".$function.$extension) {
			unlink $directoryRoot."/bin/".$function.$extension;
		}
		my $data = ['@echo off',
            'perl "'.$directoryRoot.'/config/ModelSEEDbootstrap.pm" "'.
                $directoryRoot.'/lib/ModelSEED/ModelDriver.pl" "FUNCTION:'.$function.'" '.$arguments,
            "pause"];
		printFile($directoryRoot."/bin/".$function,$data);
		chmod 0775,$directoryRoot."/bin/".$function;
	}
}
#Configuring database
{
	my $data = loadFile($directoryRoot."/config/FIGMODELConfig.txt");
	my $dbList = ["ModelDB","SchedulerDB"];
    my $configLine;
    if(lc($Config->{Database}->{type}) eq 'sqlite') {
        $configLine = "|host;".$Config->{Database}->{filename}."|type;PPO|status;1";
    } else {
        $configLine =  "|host;".$Config->{Database}->{host};
        $configLine .= "|user;".$Config->{Database}->{user};
        $configLine .= "|password;".$Config->{Database}->{password} if(defined($Config->{Database}->{password}));
        $configLine .= "|port;".$Config->{Database}->{port};
        $configLine .= "|socket;".$Config->{Database}->{socket};
        $configLine .= "|status;1|type;PPO";
    }
    foreach my $db (@$dbList) {
		for (my $i=0; $i < @{$data}; $i++) {
			if ($data->[$i] =~ m/^%PPO_tbl_(\w+)\|.*name;(\w+)\|.*table;(\w+)\|/) {
				if ($2 eq $db) {
					$data->[$i] = "%PPO_tbl_".$1."|name;".$db."|table;".$3.$configLine;
				}
			}
		}
	}
	printFile($directoryRoot."/config/FIGMODELConfig.txt",$data);
}
#Configuring MFAToolkit
{	
	if ($os ne "windows") {
		my $data = ['cd "'.$directoryRoot.'/software/mfatoolkit/Linux/"'];
		push(@{$data},'if [ "$1" == "clean" ]');
		push(@{$data},'    then make clean');
		push(@{$data},'fi');
		push(@{$data},'make');
		printFile($directoryRoot."/software/mfatoolkit/bin/makeMFAToolkit.sh",$data);
		chmod 0775,$directoryRoot."/software/mfatoolkit/bin/makeMFAToolkit.sh";
	}
	system($directoryRoot."/bin/makeMFAToolkit".$extension);
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
    my ($filename) = @_;
    my $DataArrayRef = [];
    open (INPUT, "<", $filename) || die("Couldn't open $filename: $!");
    while (my $Line = <INPUT>) {
        chomp($Line);
        push(@{$DataArrayRef},$Line);
    }
    close(INPUT);
    return $DataArrayRef;
}

# remove everything that gets added in a "load" step...
sub unload {
    # don't remove directories bin config data lib logs software
    unlink $directoryRoot."/config/FIGMODELConfig.txt"; 
    unlink $directoryRoot."/config/ModelSEEDbootstrap.pm";
    my $ext = "";
    my $os = "linux";
    if($^O =~ /cygwin/ || $^O =~ /MSWin32/) {
        $ext = ".cmd";
        $os = "windows";
    }
    # remove files from bin/ that are made w/ each load
    my $files = [ "QueueDriver".$ext,
                  "ModelDriver".$ext,
                  "CreateDBScheme".$ext,
                  "makeMFAToolkit".$ext,
                  "adduser".$ext,
                  "testmodelgrowth".$ext,
                  "importmodel".$ext,
                ];
    foreach my $filename (@$files) {
        unlink $directoryRoot."/bin/".$filename;  
    } 
    if($os eq "windows") {
        # ??? FIXME
    } else {
        chdir "$directoryRoot/software/mfatoolkit/Linux";
        system("make clean");
    }
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
