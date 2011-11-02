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
use Data::Dumper;
# Get the Installation path using what we know about the location
# of this script ( abs_path($0) is absolute path to this script )
my $directoryRoot = abs_path($0);
$directoryRoot =~ s?(.*)/lib/ModelSEED/ModelSEEDScripts/.*?$1?;
$directoryRoot = abs_path($directoryRoot);

my $args = {};
my $result = GetOptions(
    "figconfig|f=s@" => \$args->{"-figconfig"},
    "h|help" => \$args->{"help"},
    "fast|nomake" => \$args->{"fast"},
    "man" => \$args->{"man"},
);
pod2usage(1) if $args->{"help"};
pod2usage(-exitstatus => 0, -verbose => 2) if $args->{"man"};
# Reading the settings file
my $command = shift @ARGV;
unless(defined($command) && 
    ($command eq "unload" || $command eq "load" ||
     $command eq "reload" || $command eq "clean")) {
    pod2usage(2);
}
if($command eq "unload" || $command eq "clean") {
    unload($args);
    exit();
} elsif($command eq "reload") {
    unload($args);
}
my ($Config,$extension,$arguments,$delim,$os,$configFile);
#Identifying and parsing the conf file
{
	# By default use config/Settings.config
	if (-e $directoryRoot."/config/ModelSEEDbootstrap.pm") {
		do  $directoryRoot."/config/ModelSEEDbootstrap.pm";
	}
	$configFile = shift @ARGV || $ENV{MODELSEED_CONFIG} || "$directoryRoot/config/Settings.config";
    unless(-f $configFile) {
        $configFile = "$directoryRoot/lib/ModelSEED/Settings.config"
    }
	$configFile = abs_path($configFile);
	#Here we are adjusting the users config file to include changes made to the standard config
	if ($configFile ne "$directoryRoot/lib/ModelSEED/Settings.config") {
		patchconfig("$directoryRoot/lib/ModelSEED/Settings.config",$configFile);
	}
	$Config = Config::Tiny->read($configFile);
	# Setting defaults for dataDirectory,
	# database (sqlite, data/ModelDB/ModelDB.db), port if db type = mysql
	unless(defined($Config->{Optional}->{dataDirectory})) {
	    $Config->{Optional}->{dataDirectory} = "$directoryRoot/data";
	}
	unless(defined($Config->{Database}->{type})) {
	    $Config->{Database}->{type} = "sqlite";
	}
	unless(defined($Config->{Optional}->{admin_users})) {
	    $Config->{Optional}->{admin_users} = "admin";
	}
	unless(defined($Config->{Database}->{filename}) ||
	        lc($Config->{Database}->{type}) ne 'sqlite') {
	    $Config->{Database}->{filename} =
	        $Config->{Optional}->{dataDirectory} . "/ModelDB/ModelDB.db";
	}
    my $glpksol = `which glpsol`;
    chomp $glpksol;
    $glpksol =~ s/\/bin\/glpsol//;
    if(!defined($Config->{Optimizers}->{includeDirectoryGLPK}) && defined($glpksol)) {
        $Config->{Optimizers}->{includeDirectoryGLPK} = "$glpksol/include/";
    }
    if(!defined($Config->{Optimizers}->{libraryDirectoryGLPK}) && defined($glpksol)) {
        $Config->{Optimizers}->{libraryDirectoryGLPK} = "$glpksol/lib/";
    }
	if(lc($Config->{Database}->{type}) eq 'mysql' &&
	    !defined($Config->{Database}->{port})) {
	    $Config->{Database}->{port} = "3306";
	}
	# Setting paths to absolute for different configuration parameters
	foreach my $path ( 
	    qw( Optional=dataDirectory Optimizers=includeDirectoryGLPK Optimizers=libraryDirectoryGLPK
	        Optimizers=libraryDirectoryCPLEX Optimizers=licenseDirectoryCPLEX
	        Optimizers=licenseDirectoryCPLEX )) {
	    my ($section, $name) = split(/=/, $path);
	    if(defined($Config->{$section}->{$name})) {
	        $Config->{$section}->{$name} = abs_path($Config->{$section}->{$name});
	    }
	}
}	
#Setting operating system related parameters
{
	$extension = "";
	$arguments = "\$*";
	$delim = ":";
	$os = 'linux';
	# figure out OS from $^O variable for extension, arguments and delim:
	if($^O =~ /cygwin/ || $^O =~ /MSWin32/) {
	    $os = 'windows';
	} elsif($^O =~ /darwin/) {
	    $os = 'osx';
	}
}
#Creating missing directories
{
	my $directories = [qw( bin config data lib logs software workspace )];
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
            if ($data->[$i] !~ m/\/$/) {
            	$data->[$i] .= "/";
            }
        } elsif ($data->[$i] =~ m/^software\sroot\sdirectory/) {
            $data->[$i] = "software root directory|".$directoryRoot;
            if ($data->[$i] !~ m/\/$/) {
            	$data->[$i] .= "/";
            }
        } elsif ($data->[$i] =~ m/mfatoolkit\/bin\/mfatoolkit/ && $os eq "windows") {
            $data->[$i] = $data->[$i].".exe";
        } elsif ($data->[$i] =~ m/model\sadministrators\|/) {
            $data->[$i] = "%model administrators|".join("|",split(/,/,$Config->{Optional}->{admin_users}));
        }
    }
	printFile($directoryRoot."/config/FIGMODELConfig.txt",$data);
}
{ 
    # Creating config/ModelSEEDbootstrap.pm
    # and bin/source-me.sh
    my $perl5Libs = [
        "$directoryRoot/local/lib/perl5",
        "$directoryRoot/lib/PPO",
        "$directoryRoot/lib/myRAST",
        "$directoryRoot/lib/FigKernelPackages",
        "$directoryRoot/lib/ModelSEED/ModelSEEDClients/",
        "$directoryRoot/lib"
    ];
	my $figmodelConfigs = $directoryRoot."/config/FIGMODELConfig.txt";
	if (defined($args->{"-figconfig"}) && @{$args->{"-figconfig"}} > 0) {
		$args->{"-figconfig"} = [ map { $_ = abs_path($_) } @{$args->{"-figconfig"}} ];
		$figmodelConfigs .= ";".join(";",@{$args->{"-figconfig"}})
	} elsif (defined($ENV{FIGMODEL_CONFIG})) {
		$figmodelConfigs = $ENV{FIGMODEL_CONFIG};
	}
    my $envSettings = {
        MODELSEED_CONFIG => $configFile,
        MODEL_SEED_CORE => $directoryRoot,
        PATH => join("$delim", ( $directoryRoot.'/bin/',
                                 $directoryRoot.'/lib/ModelSEED/ModelSEEDScripts/',
                               )),
        FIGMODEL_CONFIG => $figmodelConfigs,
        ARGONNEDB => $Config->{Optional}->{dataDirectory}.'/ReactionDB/',
        MFATOOLKITDIR => $directoryRoot.'/software/mfatoolkit/'
    };
    if(defined($ENV{FIGMODEL_USER}) && defined($ENV{FIGMODEL_PASSWORD})) {
        $envSettings->{FIGMODEL_USER} = $ENV{FIGMODEL_USER};
        $envSettings->{FIGMODEL_PASSWORD} = $ENV{FIGMODEL_PASSWORD};
    }
    $envSettings->{CPLEXAPI} = "CPLEXapiEMPTY.cpp";
    $envSettings->{MFATOOLKITCCFLAGS} = "-O3 -fPIC -fexceptions -DNDEBUG -DIL_STD -DILOSTRICTPOD -DLINUX -I../Include/ -DNOSAFEMEM -DNOBLOCKMEM";    
    $envSettings->{MFATOOLKITCCLNFLAGS} = "";
    if(defined($Config->{Optimizers}->{includeDirectoryGLPK})) {
    	$envSettings->{MFATOOLKITCCFLAGS} .=  " -I".$Config->{Optimizers}->{includeDirectoryGLPK};
    	$envSettings->{MFATOOLKITCCLNFLAGS} .= "-L".$Config->{Optimizers}->{libraryDirectoryGLPK}." -lglpk";
    }
    if (defined($Config->{Optimizers}->{includeDirectoryCPLEX})) {
    	 $envSettings->{MFATOOLKITCCLNFLAGS} .= " -L".$Config->{Optimizers}->{libraryDirectoryCPLEX}." -lcplex -lm -lpthread -lz";
    	 $envSettings->{MFATOOLKITCCFLAGS} .= " -I".$Config->{Optimizers}->{includeDirectoryCPLEX};
    	 $envSettings->{CPLEXAPI} = "CPLEXapi.cpp";
    	 $envSettings->{ILOG_LICENSE_FILE} = $Config->{Optimizers}->{licenceDirectoryCPLEX};
    	 if ($os eq "osx") {
    	 	$envSettings->{MFATOOLKITCCLNFLAGS} .= " -framework CoreFoundation -framework IOKit";
    	 }
    }
    my $bootstrap = "";
    foreach my $lib (@$perl5Libs) {
        $bootstrap .= "use lib '$lib';\n";
    }
    $bootstrap .= "use ModelSEED::ModelDriver;\n";
    foreach my $key (keys %$envSettings) {
        next unless(defined($key) && defined($envSettings->{$key}));
        if($key eq "PATH") {
            $bootstrap .= '$ENV{'.$key.'} .= $ENV{PATH}."'.$delim.$envSettings->{$key}."\";\n";
            next;
        }
        $bootstrap .= '$ENV{'.$key.'} = "'.$envSettings->{$key}."\";\n";
    }
    $bootstrap .= <<'BOOTSTRAP';
sub run {
    if (defined($ARGV[0])) {
    	my $prog = shift(@ARGV);
    	local @ARGV = @ARGV;
    	do $prog;
    }
}
1;
BOOTSTRAP
    open(my $fh, ">", $directoryRoot."/config/ModelSEEDbootstrap.pm") || die($!);
    print $fh $bootstrap;
    close($fh);
    my $source_script = "#!/bin/sh\n";
    foreach my $lib (@$perl5Libs) {
        $source_script .= 'PERL5LIB=${PERL5LIB}'.$delim."$lib;\n";
    }
    $source_script .= "export PERL5LIB;\n";
    foreach my $key (keys %$envSettings) {
        next unless(defined($key) && defined($envSettings->{$key}));
        if($key eq "PATH") {
            $source_script .= "export $key=\${$key}$delim".$envSettings->{$key}.";\n";
        } else {
            $source_script .= "export $key=\"".$envSettings->{$key}."\";\n";
        }
    }
    open($fh, ">", $directoryRoot."/bin/source-me.sh") || die($!);
    print $fh $source_script;
    close($fh);
    chmod 0775, $directoryRoot."/bin/source-me.sh";
}
#Creating update scripts
{
	my $data = [
		"cd ".$directoryRoot,
		"git pull",
		"source bin/source-me.sh",
		"./bin/ms-config load"
	];	
	printFile($directoryRoot."/bin/ms-update",$data);
	chmod 0775,$directoryRoot."/bin/ms-update";
}
#Creating shell scripts for individual perl scripts
{
	my $mfatoolkitScript = "/lib/ModelSEED/ModelSEEDScripts/configureMFAToolkit.pl\" -p \"".$directoryRoot;
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
        "/lib/ModelSEED/ModelSEEDScripts/ms-load-mysql.pl" => "ms-load-mysql",
		$ppoScript => "CreateDBScheme",
		$mfatoolkitScript => "makeMFAToolkit",
		"/lib/ModelSEED/ModelDriver.pl" => "ModelDriver"
	};
	foreach my $file (keys(%$plFileList)) {
		if (-e $directoryRoot."/bin/".$plFileList->{$file}.$extension) {
			unlink $directoryRoot."/bin/".$plFileList->{$file}.$extension;	
		}
		my $script = <<SCRIPT;
perl -e "use lib '$directoryRoot/config/';" -e "use ModelSEEDbootstrap;" -e "run();" "$directoryRoot$file" $arguments
SCRIPT
		#if ($os eq "windows") {
        #    $script = "\@echo off\n" . $script . "pause\n";
        #}
        open(my $fh, ">", $directoryRoot."/bin/".$plFileList->{$file}.$extension) || die($!);
        print $fh $script;
        close($fh);
		chmod 0775,$directoryRoot."/bin/".$plFileList->{$file}.$extension;
	}
}
#Creating shell scripts for select model driver functions
{
	my $obsoleteList = [
		"loadmodelfromfile",
		"loadbiomassfromfile",
		"printmodelfiles",
		"logout",
		"login",
		"deleteaccount",
		"importmodel",
		"createlocaluser",
		"gapfillmodel",
		"printmedia",
		"blastgenomesequences",
		"createmedia"
	];
	my $functionList = [
		"ms-createuser",
		"ms-deleteuser",
		"ms-switchworkspace",
		"ms-workspace",
		"ms-listworkspace",
		"ms-login",
		"ms-logout",
		"sq-blastgenomes",
		"fba-checkgrowth",
		"fba-singleko",
		"fba-fva",
		"bc-printmedia",
		"bc-loadmedia",
		"mdl-autocomplete",
		"mdl-reconstruction",
		"mdl-makedbmodel",
		"mdl-addright",
		"mdl-createmodel",
		"mdl-inspectstate",
		"mdl-printsbml",
		"mdl-printmodel",
		"mdl-printmodelgenes",
		"mdl-loadmodel",
		"mdl-loadbiomass",
		"mdl-parsesbml",
		"mdl-importmodel",
		"util-matrixdist"
	];
	foreach my $function (@{$obsoleteList}) {
		if (-e $directoryRoot."/bin/".$function.$extension) {
			unlink $directoryRoot."/bin/".$function.$extension;
		}
	}
	foreach my $function (@{$functionList}) {
		if (-e $directoryRoot."/bin/".$function.$extension) {
			unlink $directoryRoot."/bin/".$function.$extension;
		}
		my $script = <<SCRIPT;
perl -e "use lib '$directoryRoot/config/';" -e "use ModelSEEDbootstrap;" -e "run();"  "$directoryRoot/lib/ModelSEED/ModelDriver.pl" "$function" $arguments
SCRIPT
        open(my $fh, ">", $directoryRoot."/bin/".$function.$extension) || die($!);
        print $fh $script;
        close($fh);
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
        $configLine .= "|user;".$Config->{Database}->{username};
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
	    my $output = [
	    'cd "'.$directoryRoot.'/software/mfatoolkit/Linux/"',
		'if [ "$1" == "clean" ]',
		'    then make clean',
		'fi',
		'make'
	    ];
	    printFile($directoryRoot."/software/mfatoolkit/bin/makeMFAToolkit.sh",$output);
	    chmod 0775,$directoryRoot."/software/mfatoolkit/bin/makeMFAToolkit.sh";
	    unless($args->{fast}) {
	    	system($directoryRoot."/bin/makeMFAToolkit");
	    }
    }
}
#Creating public useraccount
{	
	require $directoryRoot."/config/ModelSEEDbootstrap.pm";
	require ModelSEED::FIGMODEL;
	my $figmodel = ModelSEED::FIGMODEL->new();
	if ($figmodel->config("PPO_tbl_user")->{name}->[0] eq "ModelDB") {
		my $usrObj = $figmodel->database()->get_object("user",{login => "public"});
		if (!defined($usrObj)) {
			print "Creating public account for initial installation!\n";
			$usrObj = $figmodel->database()->create_object("user",{
				login => "public",
				password => "public",
				firstname => "public",
				lastname => "public",
				email => "public",
			});
			$usrObj->set_password("public");
		}
	}
}
#Printing success message
{
	if (!-e $directoryRoot."/software/mfatoolkit/bin/mfatoolkit" &&
        !defined($args->{fast}) && $os ne "windows")  {
		print "MFAToolkit compilation failed!\n"
	}
	print "Model SEED Configuration Successful!\n"
}

1;
#Utility functions used by the configuration script
sub printFile {
    my ($filename,$arrayRef) = @_;
    open ( my $fh, ">", $filename) || die("Failure to open file: $filename, $!");
    foreach my $Item (@{$arrayRef}) {
    	print $fh $Item."\n";
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

sub patchconfig {
    my ($template,$filename) = @_;
    #Loading the template config file
    my $change = 0;
    my $tempdata;
    my $templateFile = loadFile($template);
    my $heading;
    my $headingChecklist;
    for (my $i=0; $i < @{$templateFile}; $i++) {
    	if ($templateFile->[$i] =~ m/^\[(.+)\]/) {
    		$heading = $1;
    		$headingChecklist->{$heading} = 0;
    	} elsif ($templateFile->[$i] =~ m/^(#*\s*)(\w+)=(.*)$/) {
    		my ($prefix,$subheading,$suffix) = ($1,$2,$3);
    		if (defined($heading)) {
    			$tempdata->{$heading}->{$subheading}->{prefix} = $prefix || "";
    			$tempdata->{$heading}->{$subheading}->{suffix} = $suffix || "";
    		}
    	}
    }
    #Loading and adjusting the users config file:
    #Commenting out content that is no longer relevant
    #Adding content that should be there but isn't
    my $targetFile = loadFile($filename);
    undef $heading;
    for (my $i=0; $i < @{$targetFile}; $i++) {
    	if ($targetFile->[$i] =~ m/^\[(.+)\]/) {
    		my $newHeading = $1;
    		if (defined($heading) && defined($tempdata->{$heading})) {
    			foreach my $subheading (keys(%{$tempdata->{$heading}})) {
    				if (!defined($tempdata->{$heading}->{$subheading}->{found})) {
    					#Inserting missing subheading
    					splice(@{$targetFile}, $i+1, 0,$tempdata->{$heading}->{$subheading}->{prefix}.$subheading."=".$tempdata->{$heading}->{$subheading}->{suffix});
    					$change = 1;
    				}	
    			}
    		}
    		$heading = $newHeading;
    		if (defined($tempdata->{$heading})) {
    			$headingChecklist->{$heading} = 1;
    		} else {
    			$targetFile->[$i] = "# ".$targetFile->[$i].": this configuration is no longer in use and can be deleted";
    			$change = 1;
    		}
    	} elsif ($targetFile->[$i] =~ m/^(#*\s*)(\w+)=(.*)$/) {
    		my ($prefix,$subheading,$suffix) = ($1,$2,$3);
    		if (!defined($tempdata->{$heading}->{$subheading}) && $targetFile->[$i] !~ m/this\sconfiguration\sis\sno\slonger\sin\suse\sand\scan\sbe\sdeleted/) {
    			$targetFile->[$i] = "# ".$targetFile->[$i].": this configuration is no longer in use and can be deleted";
    			$change = 1;
    		} elsif (defined($tempdata->{$heading}->{$subheading})) {
    			$tempdata->{$heading}->{$subheading}->{found} = 1;
    		}
    	}
    }
    if (defined($heading) && defined($tempdata->{$heading})) {
    	foreach my $subheading (keys(%{$tempdata->{$heading}})) {
    		if (!defined($tempdata->{$heading}->{$subheading}->{found})) {
    			#Inserting missing subheading
    			push(@{$targetFile},$tempdata->{$heading}->{$subheading}->{prefix}.$subheading."=".$tempdata->{$heading}->{$subheading}->{suffix});
    			$change = 1;
    		}	
    	}
    }
    #Adding any missing headings
    foreach my $current (keys(%{$headingChecklist})) {
    	if ($headingChecklist->{$current} == 0) {
    		$change = 1;
    		push(@{$targetFile},"");
    		push(@{$targetFile},"# Adding new heading missing from current settings file");
    		push(@{$targetFile},"[".$current."]");
    		foreach my $subheading (keys(%{$tempdata->{$current}})) {
    			push(@{$targetFile},$tempdata->{$heading}->{$subheading}->{prefix}.$subheading."=".$tempdata->{$heading}->{$subheading}->{suffix});
    		}
    		$headingChecklist->{$current} = 1;
    	}
    }
    printFile($filename,$targetFile);
    if ($change == 1) {
    	print "\n\nYour configuration file was adjusted based on changes made to the installation process. Please check the file!\n\n"
    }
}

# remove everything that gets added in a "load" step...
sub unload {
    my ($args) = @_;
    # don't remove directories bin config data lib logs software
    unlink $directoryRoot."/config/FIGMODELConfig.txt"; 
    unlink $directoryRoot."/config/ModelSEEDbootstrap.pm";
    my $ext = "";
    my $os = "linux";
    if($^O =~ /cygwin/ || $^O =~ /MSWin32/) {
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
    # do make unless $args->{fast} is set
    unless($args->{fast}) {
        if($os eq "windows") {
            # ??? FIXME
        } else {
            chdir "$directoryRoot/software/mfatoolkit/Linux";
            system("make clean");
        }
    }
}

__DATA__

=head1 NAME

ms-config - configures the Model SEED installation

=head1 SYNOPSIS

ms-config [options] [command] [args...]

Commands:
    
    load config-file                Load a configuration file.
    unload                          Removes all existing configurations.
    reload config-file              Unloads all configurations and loads specified config file.
    clean                           Identical to unload

Options:

    --help [-h]                     brief help message
    --man                           returns this documentation
    --figconfig [-f]                name of additional figconfig to be loaded
    --fast [ --nomake ]             omit MFAToolkit make / make clean steps
    
=cut
