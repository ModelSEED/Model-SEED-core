# -*- perl -*-
########################################################################
# Model database interaction module
# Initiating author: Christopher Henry
# Initiating author email: chrisshenry@gmail.com
# Initiating author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 8/26/2008
########################################################################
use strict;
use warnings;
use 5.008;
use Class::ISA;
use File::Temp qw(tempfile);
use Carp qw(cluck);
use Data::Dumper;
use LWP::Simple ();
use File::Path;
use File::Copy::Recursive;
use Spreadsheet::WriteExcel;
use DBI;
use Encode;
use XML::DOM;
use SAPserver;
use ModelSEED::globals;
package ModelSEED::FIGMODEL;
our $VERSION = '0.01';
use ModelSEED::FIGMODEL::FIGMODELTable;
use ModelSEED::FIGMODEL::FIGMODELObject;
use ModelSEED::ModelSEEDUtilities::TimeZone;
use ModelSEED::ModelSEEDUtilities::JulianDay;
use ModelSEED::ModelSEEDUtilities::ParseDate;
use ModelSEED::ModelSEEDUtilities::FileIOFunctions;
use ModelSEED::FIGMODEL::FIGMODELmodel;
use ModelSEED::FIGMODEL::FIGMODELdatabase;
use ModelSEED::FIGMODEL::FIGMODELweb;
use ModelSEED::FIGMODEL::FIGMODELfba;
use ModelSEED::FIGMODEL::FIGMODELcompound;
use ModelSEED::FIGMODEL::FIGMODELreaction;
use ModelSEED::FIGMODEL::FIGMODELrole;
use ModelSEED::FIGMODEL::FIGMODELgenome;
use ModelSEED::FIGMODEL::FIGMODELmapping;
use ModelSEED::FIGMODEL::FIGMODELinterval;
use ModelSEED::FIGMODEL::FIGMODELmedia;
use ModelSEED::FIGMODEL::workspace;
use ModelSEED::FIGMODEL::queue;
use ModelSEED::MooseDB::user;

=head1 Model database interaction module

=head2 Introduction

=head2 Core Object Methods

=head3 new
Definition:
	FIGMODEL = FIGMODEL->new();
Description:
	This is the constructor for the FIGMODEL object, and it should always be used when creating a new FIGMODEL object.
	The constructor handles the configuration of the FIGMODEL object including the configuration of the database location.
=cut
sub new {
	my ($userObj, $username, $password, $configFiles) = undef;
	my $self = {FAIL => [-1],SUCCESS => [1],_debug => 0};
	bless $self;
	my $class = shift @_;
	my $args  = shift @_;
	if(ref($args) eq "HASH") {
		$username	= $args->{username} if(defined($args->{username}));
		$username	= $args->{user} if(defined($args->{user}));
		$password	= $args->{password} if(defined($args->{password}));
		$configFiles = $args->{configFiles} if(defined($args->{configFiles}));
		$userObj	 = $args->{userObj} if(defined($args->{userObj}));
	} else {
		$username = $args; # depreciated new(username,password) interface
		$password = shift @_;
	}
	#Getting the list of FIGMODELConfig files to be loaded
	my @figmodelConfigFiles;
	if (defined($ENV{"FIGMODEL_DEBUG"})) {
		$self->{_debug} = $ENV{"FIGMODEL_DEBUG"};
	}
	if(defined($configFiles)) {
		push(@figmodelConfigFiles, @$configFiles);
	}
	if(scalar(@figmodelConfigFiles) == 0) {
		# need to load something, so...
		# load a single default file from
		# 1. FIGMODEL_CONFIG env parameter
		# 2. FIG_Config.pm FIGMODEL_CONFIG global
		# 3. FIGMODELConfig.txt in FIGdisk/config/ directory
		# 4. Global default
		if (defined($ENV{"FIGMODEL_CONFIG"})) {
			$ENV{"FIGMODEL_CONFIG"} =~ s/^[A-Za-z]:/\/c/;
			$ENV{"FIGMODEL_CONFIG"} =~ s/[;:][A-Za-z]:/;\/c/g;
			@figmodelConfigFiles = split(/[:;]/,$ENV{"FIGMODEL_CONFIG"});
		} else {
			@figmodelConfigFiles = ("../config/FIGMODELConfig.txt");
		}
	}
	$self->{_configSettings} = \@figmodelConfigFiles;
	#Loading the FIGMODELConfig files
	for (my $k=0;$k < @figmodelConfigFiles; $k++) {
		$figmodelConfigFiles[$k] =~ s/^\/c\//C:\//;
		if (ref($figmodelConfigFiles[$k]) eq 'HASH') {
			my $hash_config = $figmodelConfigFiles[$k];
			for my $key (keys %$hash_config) {
			   $self->{$key} = $hash_config->{$key};
			}
		} elsif (-f $figmodelConfigFiles[$k]) {
			$self->LoadFIGMODELConfig($figmodelConfigFiles[$k],1);
		} else {
			warn "Could not locate configuration file: ".$figmodelConfigFiles[$k].", continuing to load...\n";
		}
	}
	#Getting the directory where all the model data is located
	$self->{_directory}->[0] = $self->{"database root directory"}->[0];
	#Ensuring that the MFAToolkit uses the same database directory as the FIGMODEL
	$self->{"MFAToolkit executable"}->[0] .= ' resetparameter "MFA input directory" '.$self->{"database root directory"}->[0]."ReactionDB/";
	#Creating FIGMODELdatabase object
    my $db_config = $self->_get_FIGMODELdatabase_config();
	$self->{"_figmodeldatabase"}->[0] = ModelSEED::FIGMODEL::FIGMODELdatabase->new($db_config, $self);
	$self->{"_figmodelweb"}->[0] = ModelSEED::FIGMODEL::FIGMODELweb->new($self);
	#Authenticating the user
	if (defined($userObj)) {
		$self->{_user_acount}->[0] = $userObj;
	} else {
		if (!defined($username) &&
            defined($ENV{"FIGMODEL_USER"}) &&
            defined($ENV{"FIGMODEL_PASSWORD"})) {
			$username = $ENV{"FIGMODEL_USER"};
			$password = $ENV{"FIGMODEL_PASSWORD"};
		}
		if (defined($username) && length($username) > 0 &&
            defined($password) && length($password) > 0) {
			$self->authenticate_user($username,$password);
		}
	}
	return $self;	
}

sub LoadFIGMODELConfig {
	my ($self,$file_to_load,$clearOnLoad) = @_;
	open (INPUT, "<", $file_to_load) || die($@);
	my $DatabaseData;
	while (my $Line = <INPUT>) {
		chomp($Line);
		push(@{$DatabaseData},$Line);
	}
	close(INPUT);
	for (my $i=0; $i < @{$DatabaseData}; $i++) {
		while ($DatabaseData->[$i] =~ m/\$\{([^\}]+)\}/) {
			my $var = $1;
			if (defined($self->config($var)->[0])) {
				my $value = $self->config($var)->[0];
				my $search = "\\\$\\{".$var."\\}";
				$search =~ s/\s/\\s/g;
				$DatabaseData->[$i] =~ s/$search/$value/g;
			}
		}
		my $temparray = [split(/\|/,$DatabaseData->[$i])];
		if (defined($clearOnLoad) && $clearOnLoad == 1) {
			delete $self->{substr($temparray->[0],1)};
		}
		for (my $j=1; $j < @{$temparray}; $j++) {
			if ($temparray->[0] =~ m/^%/) {
				my $keyarray = [split(/;/,$temparray->[$j])];
				if (@$keyarray > 1) {
					for (my $m=1; $m < @{$keyarray}; $m++) {
						push(@{$self->{substr($temparray->[0],1)}->{$keyarray->[0]}},$keyarray->[$m]);
					}
				} else {
					$self->{substr($temparray->[0],1)}->{$keyarray->[0]} = $j;
				}
			} else {
				$self->{$temparray->[0]}->[$j-1]= $temparray->[$j];
			}
		}
	}
}

=head3 directory
Definition:
	string:directory = FIGMODEL->directory();
Description:
	Returns the database directory for the FIGMODEL database
=cut
sub directory {
	my($self) = @_;
	return $self->{_directory}->[0];
}

sub getCache {
	my ($self,$args) = @_;
	$args = $self->process_arguments($args,["key"],{package=>"FIGMODEL",id=>"NONE"});
	if (defined($args->{error})) {return $self->new_error_message({function => "getCache",args => $args});}
	my $key = $args->{package}.":".$args->{id}.":".$args->{key};
	return $self->{_cache}->{$key};
}

sub setCache {
	my ($self,$args) = @_;
	$args = $self->process_arguments($args,["key","data"],{package=>"FIGMODEL",id=>"NONE"});
	if (defined($args->{error})) {return $self->new_error_message({function => "setCache",args => $args});}
	my $key = $args->{package}.":".$args->{id}.":".$args->{key};
	$self->{_cache}->{$key} = $args->{data};
}

sub clearAllMatchingCache {
	my ($self,$args) = @_;
	$args = $self->process_arguments($args,["key"],{package=>"FIGMODEL",id=>"NONE"});
	if (defined($args->{error})) {return $self->new_error_message({function => "clearAllMatchingCache",args => $args});}
	my $key = $args->{package}.":".$args->{id}.":".$args->{key};
	foreach my $searchkey (keys(%{$self->{_cache}})) {
		if ($searchkey =~ m/$key/) {
			delete $self->{_cache}->{$key};
		}
	}
}

=head3 fail
Definition:
	-1 = FIGMODEL->fail();
Description:
	Standard return for failed functions.
=cut
sub fail {
	return -1;
}

=head3 success
Definition:
	1 = FIGMODEL->success();
Description:
	Standard return for successful functions.
=cut
sub success {
	return 1;
}

=head3 error_message
Definition:
	void = FIGMODEL->error_message(string);
Description:
	This function not only prints errors out to the screen, it also saves errors for later reporting via other means.
=cut
sub error_message {
	my($self,$Message) = @_;
	print STDERR $Message."\n";
	return $Message;
}

=head3 new_error_message
Definition:
	{}:Output = FIGMODEL->new_error_message({
		package => "?",
		function => "?",
		message => "",
		args => {}
	})
	Output = {
		error => string:error message
	}
Description:
	Returns the errors message when FIGMODEL functions fail
=cut
sub new_error_message {
	my ($self,$args) = @_;
	$args = $self->process_arguments($args,[],{
		"package" => "FIGMODEL",
		function => "?",
		message=>"",
		args=>{}
	});
	
	my $errorMsg = $args->{"package"}.":".$args->{function}.":".$args->{message};
	if (defined($args->{args}->{error})) {
		$errorMsg .= $args->{args}->{error};
	}
	if(defined($self->{"warn_level"}) && $self->{"warn_level"} == 1) {
		warn $errorMsg."\n";
	} elsif(!defined($self->{warn_level})) {
		print STDERR $errorMsg."\n";
	}
	$args->{args}->{error} = $errorMsg;
	$args->{args}->{msg} = $errorMsg;
	$args->{args}->{success} = 0;
	return $args->{args};
}
=head3 globalMessage
Definition:
	{} = FIGMODEL->globalMessage({
		id => string(FIGMODEL->user()),
		msg => string,
		thread => string(stdout)
	});
Description:
=cut
sub globalMessage {
	my ($self,$args) = @_;
	$args = $self->process_arguments($args,["msg"],{
		id => $self->user(),
		thread => "stdout",
		callIndex => 1
	});
	my @calldata = caller($args->{callIndex});
	my @temp = split(/:/,$calldata[3]);
	my $function = pop(@temp);
	my $package = pop(@temp);
	$self->database()->create_object("message",{
		message => $args->{msg},
		function => $function,
		"package" => $package,
		"time" => ModelSEED::globals::TIMESTAMP(),
		user => $self->user(),
		id => $args->{id},
		thread => $args->{thread},
	});
}
=head3 debug_message
Definition:
	void FIGMODEL->debug_message({
		package* => string:package where error occured,
		function* => string: function where error occured,
		message* => string:error message,
		args* => {}:argument hash
	});
Description:
	This function is used to periodically print debug messages. Nothing is actually printed unless debug printing is turned on
=cut
sub debug_message {
	my($self,$args) = @_;
	if ($self->{_debug} == 1) {
		$self->new_error_message($args);
	}
}

=head3 clearing_output
Definition:
	void = FIGMODEL->clearing_output(string::folder,string::log file);
Description:
	Clears output and log file
=cut
sub clearing_output {
	my($self,$folder,$logfile) = @_;
	if ($self->{_debug} eq "1") {
		#Noting that the job is finished in the output ID table
		my $obj = $self->database()->get_object("filename",{_id=>$folder});
		if (defined($obj)) {
			$obj->finishedDate(time());
			if (-d $self->{"MFAToolkit output directory"}->[0].$folder) {
				$obj->folderExists(1);
			}
		}
	} else {		
		#Clearing the log file
		if (defined($logfile) && -e $logfile) {
			system("rm ".$self->config("database message file directory")->[0].$logfile);
		}
		#Clearing the directory of output
		$self->cleardirectory($folder);
	}
}

=head3 filename
Definition:
	my $Filename = $model->filename();
Description:
	This function generates a unique folder to print output to.
=cut
sub filename {
	my($self,$function) = @_;
	if (!defined($function)) {
		$function = "UNKNOWN";
	}
	my $obj = $self->database()->create_object("filename",{creationDate=>time(),finishedDate=>-1,folderExists=>0,user=>$self->user(),function=>$function});
	return $obj->_id();
}

=head3 cleardirectory
Definition:
	$model->cleardirectory($Directory);
Description:
	This function deletes the $Directory subdirectory of the mfatoolkit output folder.
Example:
=cut
sub cleardirectory {
	my($self,$Filename) = @_;
	my $obj = $self->database()->get_object("filename",{_id=>$Filename});
	if (defined($obj)) {
		$obj->delete();
	}
	if (defined($Filename) && length($Filename) > 0 && defined($self->{"MFAToolkit output directory"}->[0]) && length($self->{"MFAToolkit output directory"}->[0]) > 0 && -d $self->{"MFAToolkit output directory"}->[0].$Filename) {
		system ("rm -rf ".$self->{"MFAToolkit output directory"}->[0].$Filename);
	}
	return $Filename;
}

=head3 cleanup
Definition:
	FIGMODEL->cleanup();
Description:
	This function clears out old files from the MFAOutput directory, old jobs on the job scheduler, and old files from the log directory
Example:
=cut
sub cleanup {
	my($self) = @_;
	#Cleaning up files in the MFAToolkitOutput directory
	my $objs = $self->database()->get_objects("filename");
	for (my $i=0; $i < @{$objs}; $i++) {
		if (-d $self->config("MFAToolkit output directory")->[0].$objs->[$i]->_id()) {
			$objs->[$i]->folderExists(1);
			if ((time()-$objs->[$i]->creationDate()) > 432000) {
				system("rm -rf ".$self->config("MFAToolkit output directory")->[0].$objs->[$i]->_id());
				$objs->[$i]->delete();
			}
		} else {
			$objs->[$i]->folderExists(0);
			if ((time()-$objs->[$i]->creationDate()) > 432000) {
				$objs->[$i]->delete();
			}
		}	
	}
	#Cleaning up old jobs in the job scheduler
	$objs = $self->database()->get_objects("job");
	for (my $i=0; $i < @{$objs}; $i++) {
		if ($objs->[$i]->STATE() eq 2 && (time()-ModelSEED::ModelSEEDUtilities::ParseDate::parsedate($objs->[$i]->FINISHED())) > 2592000) {
			#Deleting jobs output files
			if (-e "/vol/model-prod/FIGdisk/log/QSubOutput/ModelDriver.sh.o".$objs->[$i]->PROCESSID()) {
				unlink("/vol/model-prod/FIGdisk/log/QSubOutput/ModelDriver.sh.o".$objs->[$i]->PROCESSID());
			}
			if (-e "/vol/model-prod/FIGdisk/log/QSubError/ModelDriver.sh.e".$objs->[$i]->PROCESSID()) {
				unlink("/vol/model-prod/FIGdisk/log/QSubError/ModelDriver.sh.e".$objs->[$i]->PROCESSID());
			}
			#Deleting database object
			$objs->[$i]->delete();
		}
	}
}

=head3 daily_maintenance
Definition:
	FIGMODEL->daily_maintenance();
Description:
	This function will be run on a daily basis using a cronjob. It handles database backups....
Example:
=cut
sub daily_maintenance {
	my($self) = @_;
	#ModelDB Database backups
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());
	my $directory = $self->config("database root directory")->[0]."ReactionDB/backup/";
	chdir($directory);
	my $dirname = sprintf("%d\_%02d\_%02d", $year+1900, $mon+1, $mday);
	mkdir($dirname) unless(-d $dirname);
	my $filename = $directory.$dirname."/"."ModelDBBackup.sql";
	system("mysqldump --host=bio-app-authdb.mcs.anl.gov --user=webappuser --port=3306 --socket=/var/lib/mysql/mysql.sock --result-file=".$filename." --databases ModelDB SchedulerDB");
	system("tar -czf ".$dirname.".tgz ".$dirname);
	system("chmod 666 $dirname.tgz");
	unlink($filename);
	rmdir($dirname);
	if (-e $directory."daily/".$wday.".sql.tgz") {
		unlink($directory."daily/".$wday.".sql.tgz");
	}
	system("cp ".$dirname.".tgz ".$directory."daily/".$wday.".sql.tgz");
	if ($mday == 1) {
		if (-e $directory."monthly/".$mon.".sql.tgz") {
			unlink($directory."monthly/".$mon.".sql.tgz");
		}
		system("cp ".$dirname.".tgz ".$directory."monthly/".$mon.".sql.tgz");
	}
	if (($mday % 7) == 1) {
		my $week = (($mday-1)/7)+1;
		if (-e $directory."weekly/".$week.".sql.tgz") {
			unlink($directory."weekly/".$week.".sql.tgz");
		}
		system("cp ".$dirname .".tgz ".$directory."weekly/".$week.".sql.tgz");
	}
	unlink($dirname.".tgz");
}

=head3 config
Definition:
	?::key value = FIGMODEL->config(string::key);
Description:
	Trying to avoid using calls that assume configuration data is stored in a particular manner.
	Call this function to get file paths etc.
=cut

sub config {
	my ($self,$key) = @_;
	return $self->{$key};
}

=head3 process_arguments
Definition:
	{}:arguments = FIGMODEL->process_arguments({}:arguments,[string]:mandatory arguments,{}:optional arguments);
Description:
	Processes arguments with configurable parameters
=cut
sub process_arguments {
	my ($self,$args,$mandatoryArguments,$optionalArguments) = @_;
	$args = ModelSEED::globals::ARGS($args,$mandatoryArguments,$optionalArguments);
	if (defined($args->{cgi}) || ((defined($args->{user}) || defined($args->{username})) && defined($args->{password}))) {
		$self->authenticate($args);
	}
	return $args;
}

=head3 public_compound_table 
Definition:
	FIGMODELTable = FIGMODEL->public_compound_table()
Description:
	Generates a FIGMODELTable of the public compound data in the figmodel
	biochemistry database. Used by ModelSEEDdownload.cgi to generate an
	Excel spreadsheet of the biochemistry database.
=cut
sub public_compound_table {
	my ($self) = @_;
	my $headings = [ "DATABASE", "PRIMARY NAME", "ABBREVIATION",
					 "NAMES", "KEGG ID(S)", "FORMULA", "CHARGE",
					 "DELTAG (kcal/mol)", "DELTAG ERROR (kcal/mol)", "MASS"];
	my $heading_to_cpd_attr = { "DATABASE" => "id", "PRIMARY NAME" => "name",
								"MASS" => "mass", "ABBREVIATION" => "abbrev",
								"FORMULA" => "formula", "CHARGE" => "charge",
								"DELTAG (kcal/mol)" => "deltaG",
								"DELTAG ERROR (kcal/mol)" => "deltaGErr"
							  };
	my $heading_to_other_func = {
		"NAMES" => sub {
					my $id = shift @_;
					my $names = $self->database()->get_objects("cpdals", {"COMPOUND" => $id, "type" => "name"});
					return map { $_->alias() } @$names;
				  },
		"KEGG ID(S)" => sub {
					my $id = shift @_;
					my $keggids = $self->database()->get_objects("cpdals", {"COMPOUND" => $id, "type" => "KEGG"});
					return map { $_->alias() } @$keggids;
				}
	};
	my ($fh, $filename) = File::Temp::tempfile("compound-db-XXXXXXX");
	close($fh);
	my $tbl = ModelSEED::FIGMODEL::FIGMODELTable->new($headings,$filename,undef,"\t","|",undef);	
	my $cpds = $self->database()->get_objects("compound");
	foreach my $cpd (@$cpds) {
		next unless defined $cpd;
		my $newRow = {};
		foreach my $heading (@$headings) {
			if(defined($heading_to_cpd_attr->{$heading})) {
				my $attr = $heading_to_cpd_attr->{$heading};
				$newRow->{$heading} = [$cpd->$attr()];
			} elsif(defined($heading_to_other_func->{$heading})) {
				my $func = $heading_to_other_func->{$heading};
				my @data = &$func($cpd->id());
				$newRow->{$heading} = \@data;
			}
		}
		$tbl->add_row($newRow);
	}
	return $tbl;
}


=head3 public_reaction_table 
Definition:
	FIGMODELTable = FIGMODEL->public_reaction_table()
Description:
	Generates a FIGMODELTable of the public reaction data in the figmodel
	biochemistry database. Used by ModelSEEDdownload.cgi to generate an
	Excel spreadsheet of the biochemistry database.
=cut
sub public_reaction_table {
	my ($self) = @_;
	my $headings = ["DATABASE", "NAME","EC NUMBER(S)","KEGG ID(S)",
					"DELTAG (kcal/mol)","DELTAG ERROR (kcal/mol)",  
					"EQUATION","NAME EQ","THERMODYNAMIC FEASIBILTY",
				   ];
	my $heading_to_rxn_attr = { "DATABASE" => "id", "NAME" => "name",
								"DELTAG (kcal/mol)" => "deltaG",
								"DELTAG ERROR (kcal/mol)" => "deltaGErr",
								"EQUATION" => "equation", "NAME EQ" => "definition",
								"THERMODYNAMIC FEASIBILTY" => "thermoReversibility",
								"EC NUMBER(S)" => "enzyme",
							  };
	my $heading_to_other_hash = {
		"KEGG ID(S)" => $self->database()->get_object_hash(
			{ type => "rxnals", attribute => "REACTION", parameters => { type => "KEGG" } }),
	};
	my ($fh, $filename) = File::Temp::tempfile("reaction-db-XXXXXXX");
	close($fh);
	my $tbl = ModelSEED::FIGMODEL::FIGMODELTable->new($headings,$filename,undef,"\t","|",undef);	
	my $rxns = $self->database()->get_objects("reaction");
	foreach my $rxn (@$rxns) {
		next unless defined $rxn;
		my $newRow = {};
		foreach my $heading (@$headings) {
			if(defined($heading_to_rxn_attr->{$heading})) {
				my $attr = $heading_to_rxn_attr->{$heading};
				$newRow->{$heading} = [$rxn->$attr()];
			} elsif(defined($heading_to_other_hash->{$heading})) {
				my $hash = $heading_to_other_hash->{$heading};
				my $data = defined $hash->{$rxn->id()} ? $hash->{$rxn->id()}->[0]->alias() : "";
				$newRow->{$heading} = [$data];
			}
		}
		$tbl->add_row($newRow);
	}
	return $tbl;
}

=head3 _get_FIGMODELdatabase_config
    Return subset of current configuration that is used
    by FIGMODELdatabase.
=cut
sub _get_FIGMODELdatabase_config { 
    my ($self) = @_;
    my $allowedKeys = [
        "database root directory",
        "objects with rights",
        "model administrators",
        "object types",
        "Reaction database directory",
        "locked table list filename",
        "Translation directory",
        "Media directory",
        "compound directory",
        "reaction directory",
        "MFAToolkit input files"];
    my $allowed_but_not_found = [
        "experimental data directory",
        "Metagenome directory",
    ];
    my $allowedKeysByRegex = [ qr{PPO_tbl_.*} ];
    my $config = {};
    foreach my $key (@$allowedKeys) {
        if(defined($self->config($key))) {
            $config->{$key} = $self->config($key);
        }
    }
    foreach my $key (keys %$self) {
        foreach my $regex (@$allowedKeysByRegex) {
            if($key =~ $regex) {
                $config->{$key} = $self->config($key);
            }
        }
    }
    return $config;
}

=head2 Routines that access or set other SEED modules

=head3 sapSvr
Definition:
	SAP:sapling object = FIGMODEL->sapSvr(string:target database);
Description:
=cut
sub sapSvr {
	my($self,$target) = @_;
	if (!defined($target)) {
		$target = 'PUBSEED';
	}
	$ENV{'SAS_SERVER'} = $target;
	
	return SAPserver->new();
}

=head3 server
Definition:
	server object = FIGMODEL->server(string:server name);
Description:
=cut
sub server {
	my($self,$server) = @_;
	require $server.".pm";
	return $server->new();
}

=head3 database
Definition:
	FIGMODELdatabase = FIGMODEL->database();
Description:
	Function returns FIGMODELdatabase object.
=cut
sub database {
	my($self) = @_;
	return $self->{"_figmodeldatabase"}->[0];
}

=head3 web
Definition:
	FIGMODELweb = FIGMODEL->web();
Description:
	Function returns FIGMODELweb object.
=cut
sub web {
	my($self) = @_;
	return $self->{"_figmodelweb"}->[0];
}
=head3 queue
Definition:
	queue = FIGMODEL->queue();
Description:
	Retreives the current queue object
=cut
sub queue {
	my ($self) = @_;
	if (!defined($self->{_queue})) {
		$self->{_queue} = ModelSEED::FIGMODEL::queue->new({
	        id => $self->config("Default queue")->[0],
	        type => $self->config("Default queue type")->[0],
	        user => $self->user(),
	        db => $self->database(),
	        defaultQueues => $self->config("Job specific default queues"),
	        jobdirectory => $self->config("Job file directory")->[0],
	        maxJobs => $self->config("Max file jobs")->[0],
		});
	}
	return $self->{_queue};
}

=head3 workspace
Definition:
	FIGMODELweb = FIGMODEL->workspace();
Description:
	Function returns a workspace object.
=cut
sub ws {
	my($self) = @_;
	if (!defined($self->{_workspace}->[0])) {
		$self->loadWorkspace();
	}
	return $self->{_workspace}->[0];
}
=head3 loadWorkspace
Definition:
	FIGMODELweb = FIGMODEL->loadWorkspace();
Description:
	Loads the current workspace when FIGMODEL->new() is called
=cut
sub loadWorkspace {
	my ($self) = @_;
	$self->{_workspace} = [ ModelSEED::FIGMODEL::workspace->new({
        root => $self->config("Workspace directory")->[0],
		binDirectory => $self->config("software root directory")->[0]."bin/",
		owner => $self->user(),
		clear => 0,
		copy => undef
	})];
}
=head3 switchWorkspace
Definition:
    FIGMODEL->switchWorkspace({
		name => string:new workspace name
		copy => string:name of an existing workspace to replicate
		clear => 0/1:clears the workspace directory before using it
	});
Description:
	Switches and creates a new workspace
=cut
sub switchWorkspace {
	my ($self,$args) = @_;
	$self->process_arguments($args,["name"],{
		clear => 0,
		copy => undef
	});
	my $ws = ModelSEED::FIGMODEL::workspace->new({
        root => $self->config("Workspace directory")->[0],
        binDirectory => $self->config("software root directory")->[0]."bin/",
		id => $args->{name},
		owner => $self->user(),
		clear => $args->{clear},
		copy => $args->{copy}
	});
    # Updating local cache and current.txt file
    $self->{_workspace}->[0] = $ws;
}

=head3 listWorkspaces
Definition:
    string = FIGMODEL->listWorkspaces({
        owner => username
    });
Description:
    Return a list of all workspaces owned by username.
    Default username is currently logged in user.
    
=cut
sub listWorkspaces {
    my ($self,$args) = @_;
    $self->process_arguments($args,[],{
        owner => $self->user()
    },0);
    my $owners = [$args->{owner}];
    if ($args->{owner} eq "ALL") {
        $owners = [glob($self->config("Workspace directory")->[0]."*")];
        for (my $i=0; $i < @{$owners}; $i++) {
            if ($owners->[$i] =~ m/\/([^\/]+)$/) {
                $owners->[$i] = $1;
            }
        }
    }
    my $list;
    for (my $i=0; $i < @{$owners};$i++) {
        my $tempList = [glob($self->config("Workspace directory")->[0].$owners->[$i]."/*")];
        for (my $j=0; $j < @{$tempList}; $j++) {
            if ($tempList->[$j] !~ m/current\.txt$/ && $tempList->[$j] =~ m/\/([^\/]+)$/) {
                push(@{$list},$owners->[$i].".".$1);
            }
        }
    }
    return $list;
}


=head3 mapping
Definition:
	FIGMODELmapping = FIGMODEL->mapping();
Description:
	Function returns FIGMODELmapping object.
=cut
sub mapping {
	my($self) = @_;
	if (!defined($self->{"_figmodelmapping"})){
		$self->{"_figmodelmapping"}->[0] = ModelSEED::FIGMODEL::FIGMODELmapping->new($self);	
	}
	return $self->{"_figmodelmapping"}->[0];
}

=head2 User authentification methods for accessing private objects

=head3 user
Definition:
	string:username = FIGMODEL->user();
Description:
	Returns the name of the currently logged in user
=cut
sub user {
	my($self) = @_;
	if (defined($self->{_user_acount}->[0])) {
		return $self->{_user_acount}->[0]->login();	
	}
	return "PUBLIC";
}

=head3 setuser
Definition:
	string:username = FIGMODEL->setuser(PPOObject:user object);
Description:
	Sets the user to the input object
=cut
sub setuser {
	my($self,$object) = @_;
	$self->{_user_acount}->[0] = $object;	
}

=head3 userObj
Definition:
	PPOObj:user object = FIGMODEL->userObj();
Description:
	Returns the PPO object associated with the currently logged user. Returns undefined if no user is logged in.
=cut
sub userObj {
	my($self,$userObj) = @_;
	if (defined($userObj)) {
		$self->{_user_acount}->[0] = $userObj;
	}
	if (defined($self->{_user_acount}->[0])) {
		return $self->{_user_acount}->[0];	
	}
	return undef;
}

=head3 authenticate_user
Definition:
	(fail/success)= FIGMODEL->authenticate_user(string::username,string::password);
Description:
	Attempts to log in the specified user. If log in is successfuly, the user for the FIGMODEL object is changed to the input user ID
=cut
sub authenticate_user {
	my($self,$user,$password) = @_;
	if (defined($user) && defined($password)) {
		return $self->authenticate({username => $user,password => $password});		
	}
	return undef;
}

=head3 authenticate
Definition:
	(fail/success)= FIGMODEL->authenticate({username => string:username,password => string:password,cgi => CGI:cgi object});
Description:
	Attempts to log in the specified user. If log in is successfuly, the user for the FIGMODEL object is changed to the input user ID
=cut
sub authenticate {
	my($self,$args) = @_;
	if (defined($args->{user})) {
		$args->{username} = $args->{user};
	}
	if (defined($args->{cgi})) {
		   my $session = $self->database()->create_object("session",$args->{cgi});
		   if (!defined($session) || !defined($session->user)) {
		   		return "No user logged in";
		   } else {
		   		$self->{_user_acount}->[0] = $session->user;
		   		return $self->user()." logged in";
		   }
	} elsif (defined($args->{username}) && defined($args->{password})) {
		if ($args->{username} eq "public" && $args->{password} eq "public") {
			$self->{_user_acount}->[0] = ModelSEED::MooseDB::user->new({
				login => "public",
				password => "public",
				db => $self->database()
			});
			return undef; 
		}	
		my $usrObj = $self->database()->get_object("user",{login => $args->{username}});
		if (!defined($usrObj)) {
			if (defined($ENV{"FIGMODEL_USER"})) {
				my $data = $self->database()->load_single_column_file($ENV{MODEL_SEED_CORE}."/config/ModelSEEDbootstrap.pm");
				for (my $i=0; $i < @{$data};$i++) {
					if ($data->[$i] =~ m/FIGMODEL_PASSWORD/) {
						$data->[$i] = '$ENV{FIGMODEL_PASSWORD} = "public";';
					}
					if ($data->[$i] =~ m/FIGMODEL_USER/) {
						$data->[$i] = '$ENV{FIGMODEL_USER} = "public";';
					}
				}
				$self->database()->print_array_to_file($ENV{MODEL_SEED_CORE}."/config/ModelSEEDbootstrap.pm",$data);
				ModelSEED::globals::ERROR("Environment configured to log into a nonexistant account! Automatically logging out! Please attempt to log in again!");
			} else {
				ModelSEED::globals::ERROR("No user account found with name: ".$args->{username}."!");
			}
		}
		if ($usrObj->check_password($args->{password}) == 1 || $usrObj->password() eq $args->{password}) {
			$self->{_user_acount}->[0] = $usrObj;
		} else {
			ModelSEED::globals::ERROR("Input password does not match user account!");
		}
	}
	return undef;
}

=head3 import_seed_account
Definition:
	PPOuser::newly created user object = FIGMODEL->import_seed_account({
		username => string:username,
		password => string:password
	});
Description:
	Imports the account data for the specified user from the SEED database
=cut
sub import_seed_account {
	my($self,$args) = @_;
	ModelSEED::globals::ARGS($args,["username"],{password => undef});
	#Checking that you are not already in the SEED environment
	ModelSEED::globals::ERROR("Only a valid operation on nonseed hosted systems.") if ($self->config("PPO_tbl_user")->{host}->[0] eq "bio-app-authdb.mcs.anl.gov");
	#Checking if user account already exists with specified name
	my $usrObj = $self->database()->get_object("user",{login => $args->{username}});
	ModelSEED::globals::ERROR("A user account already exists locally with the specified username. This account must be deleted!") if (defined($usrObj));
	#Getting password from user if not provided
	if (!defined($args->{password})) {
		print "Enter password for SEED account:";
		$args->{password} = <>;
	}
	#Getting user data
	my $svr = $self->server("MSSeedSupportClient");
	my $output = $svr->get_user_info({username => $args->{username},password => $args->{password}});
	if (!defined($output->{username})) {
		$self->error_message("Could not load user data from SEED server:".$output->{error});
		return undef;
	}
	#Creating the new useraccount
	$usrObj = $self->database()->create_object("user",{
		login => $output->{username},
		password => $output->{password},
		firstname => $output->{firstname},
		lastname => $output->{lastname},
		email => $output->{email},
	});
	$usrObj->_change_id($output->{id});
	#$usrObj->set_password($args->{password});
	return $usrObj;
}

=head3 logout
Definition:
	FIGMODEL->logout()
Description:
	Logs the specified user out.
=cut
sub logout {
	my ($self) = @_;
	undef $self->{_user_acount};
}

=head2 Functions relating to job queue



=head2 Object retrieval methods

=head3 get_genome
Definition:
	FIGMODELgenome = FIGMODEL->get_genome(string::genome id);
Description:
	Returns a FIGMODELgenome object for the specified genome
=cut
sub get_genome {
	my ($self,$genome) = @_;
	if (!defined($self->{_genome_cache}->{$genome})) {
		$self->{_genome_cache}->{$genome} = ModelSEED::FIGMODEL::FIGMODELgenome->new({genome => $genome});
	}
	return $self->{_genome_cache}->{$genome};
}

=head3 get_interval
Definition:
	FIGMODELinterval = FIGMODEL->get_interval(string::interval id);
Description:
	Returns a FIGMODELinterval object for the specified interval
=cut
sub get_interval {
	my ($self,$id) = @_;
	if (!defined($self->{_interval_cache}->{$id})) {
		$self->{_interval_cache}->{$id} = ModelSEED::FIGMODEL::FIGMODELinterval->new({figmodel => $self,id => $id});
	}
	return $self->{_interval_cache}->{$id};
}

=head3 get_model
Definition:
	FIGMODELmodel = FIGMODEL->get_model(int::model index || string::model id);
Description:
	Returns a FIGMODELmodel object for the specified model
=cut
sub get_model {
	my ($self,$id) = @_;
	my $cached = $self->getCache({key => $id});
	return $cached if defined($cached);
	# if cache miss:
    my $mdl = undef;
    eval {
	    $mdl = ModelSEED::FIGMODEL::FIGMODELmodel->new({
			figmodel => $self,
			id => $id
		});
        if(defined($mdl) && UNIVERSAL::isa($mdl, "ModelSEED::FIGMODEL::FIGMODELmodel")) {
            $self->setCache({key => $mdl->fullId(), data => $mdl});
        }
    };
    if($@) {
    
    }
    return $mdl;
}

=head3 get_models
Definition:
	FIGMODELmodel = FIGMODEL->get_model(int::model index || string::model id);
Description:
	Returns a FIGMODELmodel object for the specified model
=cut
sub get_models {
	my ($self,$parameters,$metagenome) = @_;
	my $models;
	if (!defined($metagenome) || $metagenome != 1) {
		$models = $self->database()->get_objects("model",$parameters);
	} else {
		$models = $self->database()->get_objects("mgmodel",$parameters);
	}
	my $results;
	if (defined($models)) {
		for (my $i=0; $i < @{$models};$i++) {
			my $newModel = $self->get_model($models->[$i]->id());
			if (defined($newModel)) {
				push(@{$results},$newModel);
			}
		}
	}
	return $results;
}

=head3 get_reaction
Definition:
	FIGMODELreaction = FIGMODEL->get_reaction(string::reaction ID);
Description:
=cut
sub get_reaction {
	my ($self,$id) = @_;
	if (!defined($id)) {
		return ModelSEED::FIGMODEL::FIGMODELreaction->new({figmodel => $self});
	}
	my $rxn = $self->getCache({key => "FIGMODELreaction:".$id});
	if (!defined($rxn)) {
		$rxn = ModelSEED::FIGMODEL::FIGMODELreaction->new({figmodel => $self,id => $id});
		if (defined($rxn) && defined($id)) {
			$self->setCache({key => "FIGMODELreaction:".$id, data => $rxn});
		}
	}
	return $rxn;
}

=head3 get_media
Definition:
	FIGMODELmedia = FIGMODEL->get_media(string::media ID);
Description:
=cut
sub get_media {
	my ($self,$id) = @_;
	if (!defined($id)) {
		return ModelSEED::FIGMODEL::FIGMODELmedia->new({figmodel => $self});
	}
	my $rxn = $self->getCache({key => "FIGMODELmedia:".$id});
	if (!defined($rxn)) {
		$rxn = ModelSEED::FIGMODEL::FIGMODELmedia->new({figmodel => $self,id => $id});
		if (defined($rxn) && defined($id)) {
			$self->setCache({key => "FIGMODELmedia:".$id, data => $rxn});
		}
	}
	return $rxn;
}

=head3 get_compound
Definition:
	FIGMODELcompound = FIGMODEL->get_compound(string::compound ID);
Description:
=cut
sub get_compound {
	my ($self,$id) = @_;
	if (!defined($id)) {
		$id = "cpd00001";
	}
	if (!defined($self->cache("FIGMODELcompound|".$id))) {
		return ModelSEED::FIGMODEL::FIGMODELcompound->new({figmodel => $self,id => $id});
	}
	return $self->cache("FIGMODELcompound|".$id);
}

=head3 get_role
Definition:
	FIGMODELrole = FIGMODEL->get_role(string::role ID);
Description:
=cut
sub get_role {
	my ($self,$id) = @_;
	if (!defined($id)) {
		return ModelSEED::FIGMODEL::FIGMODELrole->new({figmodel => $self});
	}
	my $cached = $self->getCache({key => "FIGMODELrole:".$id});
	return $cached if defined($cached);
	my $role = ModelSEED::FIGMODEL::FIGMODELrole->new({figmodel => $self,id => $id});
	if (defined($role) && defined($id)) {
		$self->setCache({key => "FIGMODELrole:".$role->id(), data => $role});
		$self->setCache({key => "FIGMODELrole:".$role->ppo()->name(), data => $role});
	}
	return $role
}

=head2 FBA related methods

=head3 fba
Definition:
	 = FIGMODEL->fba();
Description:
	Returns a FIGMODELfba object for the specified model
=cut
sub fba {
	my ($self,$args) = @_;
	$args = $self->process_arguments($args,[],{
		parameters=>{},
		filename=>undef,
		geneKO=>[],
		rxnKO=>[],
		drnRxn=>[],
		model=>undef,
		media=>undef,
		parameter_files=>["ProductionMFA"],
		options => {}
	});
	if (defined($args->{model})) {
		my $mdl = $self->get_model($args->{model});
		if (defined($mdl)) {
			return $mdl->fba($args);
		}
	} else {
		$args->{figmodel} = $self;
		return ModelSEED::FIGMODEL::FIGMODELfba->new($args);
	}
	return undef;
}
=head3 fba_run_study
=item Definition:
	Output:{} = FBAMODEL->fba_run_study({
		model => string,
		media => string,
		rxnKO => [string],
		geneKO  => [string],
		parameters => {
			singleKnockout => 0/1,
			fluxVariability => 0/1
		}
	});
	Output: {
		model => string,
		media => string,
		rxnKO => [string],
		geneKO  => [string],
		parameters => {
			singleKnockout => 0/1,
			fluxVariability => 0/1
		}
		error => string,
		msg => string,
		succees => 0/1,
		results => {
			objective => 0,
			noGrowthCompounds => [string],
			fluxes => {string,double}
		}
	}   
=item Description:
=cut

sub fba_run_study {
	my ($self, $args) = @_;
	$args = $self->process_arguments($args,["model"],{
		parameters=>{},
		media=>"Complete",
	});
	my $fbaObj = $self->fba($args);
	my $result = $fbaObj->setFBAStudy($args);
	if ($result->{success} == 0) {return $self->new_error_message($result);}
	$result = $fbaObj->parseFBAStudy({});
	if ($result->{success} == 0) {return $self->new_error_message($result);}
	return $result;
}

=head2 Genome related method

=head3 calculateClusterProperties
Definition:
	{} = FIGMODEL->calculateClusterProperties({
		directory => ?,
		filename => ?,
		distances => ?
	});
Description:
=cut
sub calculateClusterProperties {
	my ($self,$args) = @_;
	print "Calculating cluster properties...\n";
	$args = $self->process_arguments($args,["directory","filename","distances"],{});
	return $self->new_error_message({function => "calculateClusterProperties",args=>$args}) if (defined($args->{error}));
	print "Loading clusters...\n";
	my $input = $self->database()->load_single_column_file($args->{directory}.$args->{filename},"");
	my $modelData = $self->database()->get_object_hash({
		type => "model",
		attribute => "id",
		parameters => {},
		useCache => 0
	});
	my $d = $args->{distances};
	my $m;#Model pool
	my $c;#Current centers
	my $output = ["Size\tCenter\tModels\tAverage distance\tLongest distance\tAverage reactions\tAverage genes\tDistances"];
	my $outputTwo = ["Distances"];
	my $cs;
	for (my $i=1; $i < @{$input}; $i++) {
		my $data = [split(/\t/,$input->[$i])];
		if (defined($data->[1]) && $data->[0] > 0) {
			my $models = [split(/;/,$data->[1])];
			push(@{$c->{$models->[0]}},@{$models});
			push(@{$m},@{$models});
			$cs->{$models->[0]} = $data->[0];
		}
	}
	my @clusterList = keys(%{$c});
	my $interD;
	my $intraD;
	for (my $i=0; $i < @clusterList; $i++) {
		for (my $j=$i+1; $j < @clusterList; $j++) {
			push(@{$interD},$d->{$clusterList[$i]."~".$clusterList[$j]});
		}
		my $average = 0;
		my $longest = 0;
		my $aveReactions = $modelData->{$clusterList[$i]}->[0]->reactions()/$cs->{$clusterList[$i]};
		my $aveGenes = $modelData->{$clusterList[$i]}->[0]->associatedGenes()/$cs->{$clusterList[$i]};
		my $distances = [];
		for (my $j=1; $j < @{$c->{$clusterList[$i]}}; $j++) {
			$aveReactions += $modelData->{$c->{$clusterList[$i]}->[$j]}->[0]->reactions()/$cs->{$clusterList[$i]};
			$aveGenes += $modelData->{$c->{$clusterList[$i]}->[$j]}->[0]->associatedGenes()/$cs->{$clusterList[$i]};
			$average += $d->{$clusterList[$i]."~".$c->{$clusterList[$i]}->[$j]}/($cs->{$clusterList[$i]}-1);
			if ($d->{$clusterList[$i]."~".$c->{$clusterList[$i]}->[$j]} > $longest) {
				$longest = $d->{$clusterList[$i]."~".$c->{$clusterList[$i]}->[$j]};	
			}
			push(@{$distances},$d->{$clusterList[$i]."~".$c->{$clusterList[$i]}->[$j]});
		}
		push(@{$intraD},@{$distances});
		my $line = [
			$cs->{$clusterList[$i]},
			$clusterList[$i],
			join(";",@{$c->{$clusterList[$i]}}),
			$average,
			$longest,
			$aveReactions,
			$aveGenes,
			join(";",@{$distances})
		];
		push(@{$output},join("\t",@{$line}));
	}
	push(@{$outputTwo},"Intracluster distances:".join(";",@{$intraD}));
	push(@{$outputTwo},"Intercluster distances:".join(";",@{$interD}));
	$self->database()->print_array_to_file($args->{directory}."ClusterData.txt",$output);
	$self->database()->print_array_to_file($args->{directory}."ClusterDistances.txt",$outputTwo);
}
=head3 optimizeClusters
Definition:
	{} = FIGMODEL->optimizeClusters({
		directory => ?,
		filename => ?,
		distances => ?
	});
Description:
	This algorithm readjusts the cluster membership and cluster centers to identify best possible centers and best possible clusters
=cut
sub optimizeClusters {
	my ($self,$args) = @_;
	print "Calculating clusters...\n";
	$args = $self->process_arguments($args,["directory","filename","distances"],{});
	return $self->new_error_message({function => "optimizeClusters",args=>$args}) if (defined($args->{error}));
	print "Loading clusters...\n";
	my $input = $self->database()->load_single_column_file($args->{directory}.$args->{filename},"");
	my $d = $args->{distances};
	my $m;#Model pool
	my $c;#Current centers
	my $output = ["Size\tCluster"];
	for (my $i=1; $i < @{$input}; $i++) {
		my $data = [split(/\t/,$input->[$i])];
		if (defined($data->[1]) && $data->[0] > 0) {
			if ($data->[0] <= 2) {
				if (defined($c)) {
					push(@{$m},split(/;/,$data->[1]));
				} else {
					push(@{$output},$input->[$i]);
				}
			} else {
				my $models = [split(/;/,$data->[1])];
				push(@{$c},shift(@{$models}));
				push(@{$m},@{$models});
			}
		}
	}
	print "Optimizing clusters...\n";
	my $cl;
	my $continue = 1;
	while ($continue == 1) {
		$cl = {};
		print "Adjusting cluster membership...\n";
		for (my $i=0; $i < @{$m}; $i++) {
			my $closest = "";
			my $distance = -1;
			for (my $j=0; $j < @{$c}; $j++) {
				if ($distance == -1 || $distance > $d->{$m->[$i]."~".$c->[$j]}) {
					$closest = $c->[$j];
					$distance = $d->{$m->[$i]."~".$c->[$j]};
				}
			}
			push(@{$cl->{$closest}},$m->[$i]);
		}
		print "Recalculating centers...\n";
		my $newCenters;
		my $changed = 0;
		for (my $j=0; $j < @{$c}; $j++) {
			my $list = $cl->{$c->[$j]};
			push(@{$list},$c->[$j]);
			my $newCenter = "";
			my $bestScore = -1;
			for (my $i=0; $i < @{$list}; $i++) {
				my $score = 0;
				for (my $k=0; $k < @{$list}; $k++) {
					if ($i != $k) {
						$score += $d->{$list->[$i]."~".$list->[$k]}*$d->{$list->[$i]."~".$list->[$k]};
					}
				}
				if ($bestScore == -1 || $bestScore > $score) {
					$newCenter = $list->[$i];
				}
			}
			if ($newCenter ne $c->[$j]) {
				$changed++;	
			}
			push(@{$newCenters},$newCenter);
		}
		$c = $newCenters;	
		print "Changed centers:".$changed."\n";
		if ($changed < 2) {
			$continue = 0;
		}
	}
	$cl = {};
	print "Adjusting final cluster membership...\n";
	for (my $i=0; $i < @{$m}; $i++) {
		my $closest = "";
		my $distance = -1;
		for (my $j=0; $j < @{$c}; $j++) {
			if ($distance == -1 || $distance > $d->{$m->[$i]."~".$c->[$j]}) {
				$closest = $c->[$j];
				$distance = $d->{$m->[$i]."~".$c->[$j]};
			}
		}
		push(@{$cl->{$closest}},$m->[$i]);
	}
	print "Printing final clusters...\n";
	for (my $j=0; $j < @{$c}; $j++) {
		my $size = @{$cl->{$c->[$j]}};
		push(@{$output},($size+1)."\t".$c->[$j].";".join(";",@{$cl->{$c->[$j]}}));
	}
	$self->database()->print_array_to_file($args->{directory}."New".$args->{filename},$output);
}
=head3 calculateModelDistances
Definition:
	{} = FIGMODEL->calculateModelDistances({
		directory => ?,
		loadFromFile => 1,
		saveToFile => 1,
		models => []
	});
Description:
	This function calculates the all vs all distances between the input set of models
=cut
sub calculateModelDistances {
	my ($self,$args) = @_;
	$args = $self->process_arguments($args,["directory"],{
		loadFromFile => 1,
		saveToFile => 1,
		models => []
	});
	return $self->new_error_message({function => "calculateModelDistances",args=>$args}) if (defined($args->{error}));
	my $distances;
	if ($args->{loadFromFile} == 1 && -e $args->{directory}."ModelDistances.txt") {
		print "Loading model distances from file...\n";
		my $input = $self->database()->load_single_column_file($args->{directory}."ModelDistances.txt","");
		return $self->new_error_message({message=>"Data not found in input file",function => "calculateModelDistances",args=>$args}) if (!defined($input->[0]));
		$args->{models} = [split(/\t/,$input->[0])];
		my $array;
		for (my $i=1; $i < @{$input}; $i++) {
			my $rowData = [split(/\t/,$input->[$i])];
			if (defined($rowData->[1])) {
				for (my $j=1; $j < @{$rowData}; $j++) {
					if (($i+$j-1) < @{$args->{models}}) {
						$distances->{$rowData->[0]."~".$args->{models}->[$i+$j-1]} = $rowData->[$j];
						$distances->{$args->{models}->[$i+$j-1]."~".$rowData->[0]} = $rowData->[$j];
						push(@{$array},$rowData->[0]."\t".$args->{models}->[$i+$j-1]."\t".$rowData->[$j]);
					}
				}
			}
		}
		$self->database()->print_array_to_file($args->{directory}."ColumnDistances.txt",$array);
	} else {
		my $rxn_mdls_hash = {};
		print "Getting model reaction data...\n";
		for (my $i=0; $i < @{$args->{models}}; $i++) {
			print "Getting data for model ".$i."...\n";
			my $rxn_mdls = $self->database()->get_objects("rxnmdl",{MODEL=>$args->{models}->[$i]});
			foreach my $rxnmdl (@$rxn_mdls) {
				next unless(defined($rxnmdl));
				if ($rxnmdl->pegs() !~ m/GAP/ && $rxnmdl->pegs() !~ m/AUTO/) {#Filtering out any gapfilling that's present
					$rxn_mdls_hash->{$rxnmdl->MODEL()}->{$rxnmdl->REACTION().$rxnmdl->compartment()} = 1;
				}
			}
		}
		print "Calculating distances for all models...\n";
		my $del = "~";
		foreach my $m (@{$args->{models}}) {
			foreach my $n (@{$args->{models}}) {
				if($m ne $n) {
					if(defined($distances->{$n."~".$m})) {
						 $distances->{$m."~".$n} = $distances->{$n."~".$m};
					} else {
						my $one = 0;
						my $two = 0;
						foreach my $rxn (keys %{$rxn_mdls_hash->{$m}}) {
						   $one++ unless(defined($rxn_mdls_hash->{$n}->{$rxn}));
						} 
						foreach my $rxn (keys %{$rxn_mdls_hash->{$n}}) {
						   $two++ unless(defined($rxn_mdls_hash->{$m}->{$rxn}));
						}
						$distances->{$m."~".$n} = sqrt($one*$one+$two*$two);
					}
				}
			}
		}
	}
	if ($args->{saveToFile} == 1 && -d $args->{directory}) {
		my $output = [join("\t",@{$args->{models}})];
		for (my $i=0; $i < @{$args->{models}}; $i++) {
			my $line = $args->{models}->[$i];
			for (my $j=$i+1; $j < @{$args->{models}}; $j++) {
				$line .= "\t".$distances->{$args->{models}->[$i]."~".$args->{models}->[$j]}
			}
			push(@{$output},$line);
		}
		$self->database()->print_array_to_file($args->{directory}."ModelDistances.txt",$output);
	}
	return $distances;
}
=head3 clusterModels
Definition:
	{} = FIGMODEL->clusterModels({
		directory => ?,
		distances => ?,
		models => ?,
		maxDistanceInCluster => ?
	});
Description:
	Clusters the models with their closest neighbors using a greedy algorithm
=cut
sub clusterModels {
	my ($self,$args) = @_;
	print "Calculating clusters...\n";
	$args = $self->process_arguments($args,["directory","distances","models","maxDistanceInCluster"],{});
	return $self->new_error_message({function => "clusterModels",args=>$args}) if (defined($args->{error}));
	my $m = $args->{models};
	my $d = $args->{distances};
	my $c;
	my $output = ["Cluster size\tCluster models"];
	my $currentCluster = [];
	my $currentSize = 0;
	my $num = @{$m};
	my $total = 0;
	my $oneClusters = 0;
	#Tuning clusters
	do {
		$currentCluster = [];
		$currentSize = 0;
		$total = 0;
		$oneClusters = 0;
		my $remaining = 0;
		for (my $i=0; $i < @{$m}; $i++) {
			if (!defined($c->{$m->[$i]})) {#Checking that model is not already part of another cluster
				$remaining++;
				my $newCluster = [$m->[$i]];
				my $newSize = 0;
				for (my $j=0; $j < @{$m}; $j++) {
					if ($j != $i && !defined($c->{$m->[$j]}) && $d->{$m->[$i]."~".$m->[$j]} < $args->{maxDistanceInCluster}) {#Checking that model is not already part of another cluster
						push(@{$newCluster},$m->[$j]);
					}
				}
				$newSize = @{$newCluster};
				$total += $newSize;
				if ($newSize <= 2) {
					push(@{$output},$newSize."\t".join(";",@{$newCluster}));
					for (my $i=0; $i < @{$newCluster}; $i++) {
						$c->{$newCluster->[$i]} = 1;
					}
					$remaining += (-1*$newSize);
					$oneClusters++;
				}
				if ($newSize > $currentSize) {
					$currentCluster = $newCluster;
					$currentSize = $newSize;
				}
			}
		}
		for (my $i=0; $i < @{$currentCluster}; $i++) {
			$c->{$currentCluster->[$i]} = 1;
		}
		print "Remaining models:".($remaining - $currentSize)."\n";
		push(@{$output},$currentSize."\t".join(";",@{$currentCluster}));
	} while ($currentSize > 0);
	$self->database()->print_array_to_file($args->{directory}."ModelClusters.txt",$output);
}
=head3 parseSBMLToTable
Definition:
	{} = FIGMODEL->parseSBMLToTable({
		directory => "",
		file => "" 
	});
Description:
	Translates SBML file to tab delimited table
=cut
sub parseSBMLToTable {
    my ($self,$args) = @_;
    #Seaver 07/07/11
    #Processing file or directory
    if(defined($args->{directory})){
	if(substr($args->{directory},-1) ne "/"){
	    $args->{directory}.="/";
	}
	
	if(!defined($args->{error}) && !-d $args->{directory}){
	    $args->{error}="Value for directory parameter (".$args->{directory}.") is not a directory\n";
	}
	
	my $dir = $args->{directory};
	my $name = $args->{model_name};
	$name = "ModelData" if !$name;
	$name.="-";
	
	$args = $self->process_arguments($args,["directory"],{
	    SBMLFile => $dir."ModelData.xml",
	    compartmentFiles => $dir.$name."compartments.tbl",
	    compoundFiles => $dir.$name."compounds.tbl",
	    reactionFiles => $dir.$name."reactions.tbl"
					 });
	
	if(!defined($args->{error}) && !-f $args->{SBMLFile}){
	    $args->{error}=" SBML File (".$args->{SBMLFile}.") not found\n";
	}
	
    }elsif(defined($args->{file})){
	my $dir=substr($args->{file},0,rindex($args->{file},'/')+1);
	my $name = $args->{model_name};
	$name = substr($args->{file},rindex($args->{file},'/')+1,rindex($args->{file},'.')-rindex($args->{file},'/')-1) if !$name;
	$name.="-";

	$args = $self->process_arguments($args,["file"],{
	    SBMLFile => $args->{file},
	    compartmentFiles => $dir.$name."compartments.tbl",
	    compoundFiles => $dir.$name."compounds.tbl",
	    reactionFiles => $dir.$name."reactions.tbl"
					 });
	
	if(!defined($args->{error}) && !-f $args->{SBMLFile}){
	    $args->{error}=" SBML File (".$args->{SBMLFile}.") not found\n";
	}
	
    }
    
    return $self->new_error_message({function => "parseSBMLtoTable",args=>$args}) if (defined($args->{error}));
    
    my $parser = XML::DOM::Parser->new();
    my $doc = $parser->parsefile($args->{SBMLFile});
    my $TableList = {};
    my %HeadingTranslation=();
    my %TableHeadings = ("id"=>0,"KEGG"=>1,"METACYC"=>2,"name"=>3,"abbrev"=>4,"charge"=>5,"mass"=>6,"compartment"=>7,
			 "reversible"=>8,"formula"=>9,"equation"=>10,"pegs"=>11,"enzymes"=>12,
			 "reference"=>13,"notes"=>14,);

    my @cmpts = $doc->getElementsByTagName("compartment");
    my %cmptAttrs=();
    my $name="";

    foreach my $cmpt (@cmpts){
	foreach my $attr( grep { !exists($HeadingTranslation{$_}) } $cmpt->getAttributes()->getValues()){
	    $name=$attr->getName();
	    $HeadingTranslation{$name}=uc($name);
	    $HeadingTranslation{$name} .= ($name eq "name") ? "S" : "";
	    $cmptAttrs{$HeadingTranslation{$name}}= (exists($TableHeadings{$attr->getName()})) ? $TableHeadings{$attr->getName()} : 100;
	}
    }

    $TableList->{compartment}=ModelSEED::FIGMODEL::FIGMODELTable->new([ sort { $cmptAttrs{$a} <=> $cmptAttrs{$b} } keys %cmptAttrs],
									 $args->{compartmentFiles},undef,"\t","|",undef);
    foreach my $cmpt (@cmpts){
	my $row={};
	foreach my $attr($cmpt->getAttributes()->getValues()){
	    $row->{$HeadingTranslation{$attr->getName()}}->[0]=$attr->getValue();
	}
	$TableList->{compartment}->add_row($row);
    }

    my @cmpds = $doc->getElementsByTagName("species");
    my %cmpdAttrs=();

    #go through all compounds in case of irregular attributes
    foreach my $cmpd(@cmpds){
	foreach my $attr($cmpd->getAttributes()->getValues()){
	    $name=$attr->getName();
	    $HeadingTranslation{$name}=uc($name);
	    $HeadingTranslation{$name} .= ($name eq "name") ? "S" : "";
	    $cmpdAttrs{$HeadingTranslation{$name}}= (exists($TableHeadings{$attr->getName()})) ? $TableHeadings{$attr->getName()} : 100;
	}
    }

    #Add kegg and metacyc
    $cmpdAttrs{KEGG}=$TableHeadings{KEGG};
    $cmpdAttrs{METACYC}=$TableHeadings{METACYC};

    my %CmpdCmptTranslation=();
    $TableList->{compound} = ModelSEED::FIGMODEL::FIGMODELTable->new([ sort { $cmpdAttrs{$a} <=> $cmpdAttrs{$b} } keys %cmpdAttrs],
								     $args->{compoundFiles},undef,"\t","|",undef);

    foreach my $cmpd (@cmpds){
	my $row={};
	foreach my $attr($cmpd->getAttributes()->getValues()){
#	    print $attr->getName(),"\n";
	    $row->{$HeadingTranslation{$attr->getName()}}->[0]=$attr->getValue();
	    if($attr->getValue() =~ /([CG]\d{5})/){
		$row->{KEGG}->[0]=$1;
	    }
	}
	$CmpdCmptTranslation{$row->{ID}->[0]}=$row->{COMPARTMENT}->[0];
	$row->{METACYC}->[0]="";
	$row->{KEGG}->[0]="" if !exists($row->{KEGG});
	$TableList->{compound}->add_row($row);
    }

    my @rxns = $doc->getElementsByTagName("reaction");
    my %rxnAttrs=();
    foreach my $attr($rxns[0]->getAttributes()->getValues()){
	$name=$attr->getName();
	$HeadingTranslation{$name}=uc($name);
	$HeadingTranslation{$name} .= ($name eq "name") ? "S" : "";
	$HeadingTranslation{$name} = ($name eq "reversible") ? "DIRECTIONALITY" : $HeadingTranslation{$name};
	$rxnAttrs{$HeadingTranslation{$name}}= (exists($TableHeadings{$attr->getName()})) ? $TableHeadings{$attr->getName()} : 100;
    }

    my $nodehash={};
    foreach my $node($rxns[0]->getElementsByTagName("*",0)){
	next if $node->getNodeName() =~ "^listOf";
	my $path=$node->getNodeName();
	traverse_sbml($node,"",$path,$nodehash);
    }
    foreach my $key (keys %$nodehash){
	$HeadingTranslation{$key}=uc($key);
	$HeadingTranslation{$key} = ($key eq "annotation") ? "NOTES" : $HeadingTranslation{$key};
	$rxnAttrs{$HeadingTranslation{$key}}= (exists($TableHeadings{$key})) ? $TableHeadings{$key} : 100;
    }

    #add equation/pegs
    $rxnAttrs{EQUATION}=$TableHeadings{"equation"};
    $rxnAttrs{PEGS}=$TableHeadings{"pegs"};
    $rxnAttrs{COMPARTMENT}=$TableHeadings{"compartment"};
    $rxnAttrs{ENZYMES}=$TableHeadings{"enzymes"};

    $TableList->{reaction} = ModelSEED::FIGMODEL::FIGMODELTable->new([ sort { $rxnAttrs{$a} <=> $rxnAttrs{$b} } keys %rxnAttrs],
								     $args->{reactionFiles},undef,"\t","|",undef);
    foreach my $rxn (@rxns){
	my $row={};
	#default for DIRECTIONALITY
	$row->{DIRECTIONALITY}->[0] = "<=>";
	foreach my $attr($rxn->getAttributes()->getValues()){
	    $row->{$HeadingTranslation{$attr->getName()}}->[0]=$attr->getValue();
	    if($attr->getName() eq "reversible"){
		$row->{DIRECTIONALITY}->[0]="=>" if $attr->getValue() eq "false";
		$row->{DIRECTIONALITY}->[0]="<=>" if $attr->getValue() eq "true";
	    }
	}

	my $nodehash={};
	foreach my $node($rxn->getElementsByTagName("*",0)){
	    next if $node->getNodeName() =~ "^listOf";
	    my $path=$node->getNodeName();
	    traverse_sbml($node,"",$path,$nodehash);
	}
	foreach my $key (keys %$nodehash){
	    $row->{$HeadingTranslation{$key}}->[0]=join("|",sort keys %{$nodehash->{$key}});
	}
	$row->{EQUATION}->[0]=join(" ",@{$self->get_reaction_equation_sbml($rxn,\%CmpdCmptTranslation)});
	$row->{PEGS}->[0]="";
	$row->{COMPARTMENT}->[0]="c";
	$row->{ENZYMES}->[0]="";
	$TableList->{reaction}->add_row($row);
    }

    return $TableList;
}

=head3 traverse_sbml
Definition:
	FIGMODEL->traverse_sbml($SBML_Node);
=cut
sub traverse_sbml {
    my $node=shift;
    my $prev_path=shift;
    my $path=shift;
    my $nodehash=shift;
    my @children=$node->getElementsByTagName("*",0);

    if(scalar(@children)==0){
	my $textstring=undef;
	$textstring=$node->getFirstChild()->getNodeValue() if $node->hasChildNodes();
	$nodehash->{$path}{$textstring}=1 if defined($textstring);
	foreach my $attr(@{$node->getAttributes()->getValues()}){
	    $nodehash->{$path}{$attr->getName().":".$attr->getValue()}=1;
	}
	return $prev_path;
    }

    foreach my $n (@children){
	$prev_path=$path;
	unless($path =~ /a?n{1,2}ot[ea][st]/i){  #Notes and Annotation fields have needless <html> and <p> elements
	    $path.="|" if $path ne "";
	    $path.=$n->getNodeName();
	}
	$path=traverse_sbml($n,$prev_path,$path,$nodehash);
    }
    return $path;
}

=head3 get_reaction_equation_sbml
Definition:
	FIGMODEL->get_reaction_equation_sbml($SBML_Reaction_Object, $Compartments);
=cut
sub get_reaction_equation_sbml {
    my ($self, $rxn, $cmptsearch) = @_;
    my $eq = [];
    my $attr = $rxn->getAttribute("reversible");
    my $reversable="<=>";

    if(defined($attr) && $attr eq "false"){
	$reversable = "=>";
    }

    my @reactants = $rxn->getElementsByTagName("listOfReactants");
    my @products = $rxn->getElementsByTagName("listOfProducts");
    if(@reactants) {
	@reactants = $reactants[0]->getElementsByTagName("speciesReference");
	for(my $i=0; $i<@reactants; $i++) {
	    push(@$eq, "+") unless($i == 0);
	    push(@$eq, @{expand_sbml_reaction_participant($reactants[$i],$cmptsearch)});
	}
    }
    push(@$eq, $reversable);
    if(@products) {
	@products = $products[0]->getElementsByTagName("speciesReference"); 
	for(my $i=0; $i<@products; $i++) {
	    push(@$eq, "+") unless($i == 0);
	    push(@$eq, @{expand_sbml_reaction_participant($products[$i],$cmptsearch)});
	}
    }
    return $eq;
}

sub expand_sbml_reaction_participant {
    my $species = shift;
    my $cmptsearch = shift;
    my $text = [];

    my $count = $species->getAttribute("stoichiometry");
    $count = undef if ( defined($count) && ($count eq "1" || $count eq "") );
    $count = abs($count) if defined($count); #avoids negative stoichiometry, yea, it happens(!)
    push(@$text,"(".$count.")") if defined($count);
    
    my $cpd = $species->getAttribute("species");
    my $cmpt= (exists($cmptsearch->{$cpd})) ? $cmptsearch->{$cpd} : "NULL";
    push(@$text,$cpd."[".$cmpt."]");
    return $text;
}

=head3 get_genome_stats
Definition:
	{[string]}::genome stats = FIGMODEL->get_genome_stats(string::genome ID);
Description:
	This function is used to pull genome stats if they are present in the genome stats table
=cut
sub get_genome_stats {
	my ($self,$genomeid) = @_;
	my $genome = $self->get_genome($genomeid);
	if (!defined($genome)) {
		return undef;
	}
	return $genome->genome_stats();
}

=head3 change_genome_cellwalltype
Definition:
	FIGMODEL->change_genome_cellwalltype(string::genome ID,string:cell wall type);
Description:
	This function is used to change the class of a genome in the genome stats table
=cut
sub change_genome_cellwalltype {
	my ($self,$genomeid,$newClass) = @_;
	my $genome = $self->get_genome($genomeid);
	if (!defined($genome)) {
		$self->error_message("FIGMODEL:could not find ".$genomeid." when trying to change class");
	}
	$genome->class($newClass);
}



=head3 subsystem_is_valid
Definition:
	(0/1) = $model->subsystem_is_valid($Subsystem);
Description:
	Checks if the input subsystem is valid
=cut
sub subsystem_is_valid {
	my ($self,$Subsystem) = @_;

	if ($Subsystem eq "NONE" || length($Subsystem) == 0) {
		return 0;
	}
	my $SubsystemClass = $self->class_of_subsystem($Subsystem);
	if (!defined($SubsystemClass) || $SubsystemClass->[0] =~ m/Experimental\sSubsystems/i || $SubsystemClass->[0] =~ m/Clustering\-based\ssubsystems/i) {
		return 1;
	}
	return 0;
}

=head2 Biochemistry database related methods

=head3 add_reaction_role_mapping
Definition:
	FIGMODEL->add_reaction_role_mapping([string]:reactions,[string]:roles);
=cut

sub add_reaction_role_mapping {
	my($self,$reactions,$roles,$types) = @_;
	#Getting existing complexes
	my $cpxHash;
	my $cpxroles = $self->database()->get_objects("cpxrole");
	for (my $j=0; $j < @{$cpxroles}; $j++) {
		$cpxHash->{$cpxroles->[$j]->COMPLEX()}->{$cpxroles->[$j]->ROLE()} = 1;
	}
	my $cpxRoles;
	my @cpxs = keys(%{$cpxHash});
	for (my $j=0; $j < @cpxs; $j++) {
		$cpxRoles->{join("|",sort(keys(%{$cpxHash->{$cpxs[$j]}})))} = $cpxs[$j];
	}
	#Getting role IDs for all input roles
	my $roleIDs;
	for (my $i=0; $i < @{$roles}; $i++) {
		my $role = $self->convert_to_search_role($roles->[$i]);
		my $roleobj = $self->database()->get_object("role",{searchname => $role});
		if (!defined($roleobj)) {
			my $newRoleID = $self->database()->check_out_new_id("role");
			my $roleMgr = $self->database()->get_object_manager("role");
			$roleobj = $roleMgr->create({id=>$newRoleID,name=>$roles->[$i],searchname=>$role});	
		}
		push(@{$roleIDs},$roleobj->id());
	}
	#Creating a new complex if one does not already exist
	my $cpxID;
	if (!defined($cpxRoles->{join("|",sort(@{$roleIDs}))})) {
		$cpxID = $self->database()->check_out_new_id("complex");
		my $cpxMgr = $self->database()->get_object_manager("complex");
		my $newCpx = $cpxMgr->create({id=>$cpxID});
		#Adding roles to new complex
		for (my $i=0; $i < @{$roleIDs}; $i++) {
			my $cpxRoleMgr = $self->database()->get_object_manager("cpxrole");
			$cpxRoleMgr->create({COMPLEX=>$cpxID,ROLE=>$roleIDs->[$i],type=>$types->[$i]});
		}
	} else {
		$cpxID = $cpxRoles->{join("|",sort(@{$roleIDs}))};
	}
	#Adding the complex to the reaction complex table
	for (my $i=0; $i < @{$reactions}; $i++) {
		my $rxnCpxObj = $self->database()->get_object("rxncpx",{REACTION=>$reactions->[$i],COMPLEX=>$cpxID});
		if (defined($rxnCpxObj)) {
			$rxnCpxObj->master(1);	
		} else {
			my $rxncpxMgr = $self->database()->get_object_manager("rxncpx");
			$rxncpxMgr->create({REACTION=>$reactions->[$i],COMPLEX=>$cpxID,master=>1});
		}
	}
}

=head3 printReactionDBTable
Definition:
	void FIGMODEL->printReactionDBTable(optional string:output directory);
Description:
=cut

sub printReactionDBTable {
	my($self,$directory) = @_;
	if (!defined($directory)) {
		$directory = $self->config("Reaction database directory")->[0]."masterfiles/";
	}
	my $objs = $self->database()->get_objects("reaction");
	my $outputArray = ["DATABASE	NAME	EQUATION	ENZYME	THERMODYNAMIC REVERSIBILITY	DELTAG	DELTAGERR	BALANCE	TRANSPORTED ATOMS"];
	for (my $i=0; $i < @{$objs}; $i++) {
		my $enzyme = $objs->[$i]->enzyme();
		if (defined($enzyme) && length($enzyme) > 0) {
			$enzyme = substr($enzyme,1,length($enzyme)-2);
		} else {
			$enzyme = "";
		}
		my $deltaG = "";
		my $deltaGErr = "";
		if (defined($objs->[$i]->deltaG()) && $objs->[$i]->deltaG() ne "10000000") {
			$deltaG = $objs->[$i]->deltaG();
			$deltaGErr = $objs->[$i]->deltaGErr();
		}
		my $line = $objs->[$i]->id()."\t".$objs->[$i]->name()."\t".$objs->[$i]->equation()."\t".$enzyme."\t".$objs->[$i]->reversibility()."\t".$deltaG."\t".$deltaGErr."\t".$objs->[$i]->status()."\t".$objs->[$i]->transportedAtoms();
		push(@{$outputArray},$line);
	}
	$objs = $self->database()->get_objects("bof");
	for (my $i=0; $i < @{$objs}; $i++) {
		if ($objs->[$i]->equation() ne "NONE") {
			my $line = $objs->[$i]->id()."\tBiomass\t".$objs->[$i]->equation()."\t\t\t\t\t\t";
			push(@{$outputArray},$line);
		}
	}
	$self->database()->print_array_to_file($directory."ReactionDatabase.txt",$outputArray);
}

=head3 get_compound_hash
Definition:
	{string:compound id => PPOcompound:compound object} = FIGMODEL->get_compound_hash();
Description:
=cut
sub get_compound_hash {
	my($self) = @_;
	if (!defined($self->{_compoundhash})) {
		my $objs = $self->database()->get_objects("compound");
		for (my $i=0; $i < @{$objs}; $i++) {
			$self->{_compoundhash}->{$objs->[$i]->id()} = $objs->[$i];
		}
	}
	return $self->{_compoundhash};
}

=head3 get_map_hash
Definition:
	{string:reaction id => PPOdiagram:diagram object} = FIGMODEL->get_map_hash({type => string:entity type});
Description:
=cut
sub get_map_hash {
	my($self,$args) = @_;
	$args = $self->process_arguments($args,["type"],{});
	if (!defined($self->{_maphash}->{$args->{type}})) {
		my $objs = $self->database()->get_objects("diagram",{type => "KEGG"});
		my $mapHash;
		for (my $i=0; $i < @{$objs}; $i++) {
			$mapHash->{$objs->[$i]->id()} = $objs->[$i];
		}
		my $entobjs = $self->database()->get_objects("dgmobj",{entitytype => $args->{type}});
		for (my $i=0; $i < @{$entobjs}; $i++) {
			$self->{_maphash}->{$args->{type}}->{$entobjs->[$i]->entity()}->{$entobjs->[$i]->DIAGRAM()} = $mapHash->{$entobjs->[$i]->DIAGRAM()};
		}
	}
	return $self->{_maphash}->{$args->{type}};
}

=head3 printCompoundDBTable
Definition:
	void FIGMODEL->printCompoundDBTable(optional string:output directory);
Description:
=cut

sub printCompoundDBTable() {
	my($self,$directory) = @_;
	if (!defined($directory)) {
		$directory = $self->config("Reaction database directory")->[0]."masterfiles/";
	}
	my $objs = $self->database()->get_objects("compound");
	my $outputArray = ["DATABASE	NAME	FORMULA	CHARGE	DELTAG	DELTAGERR	MASS	KEGGID"];
	for (my $i=0; $i < @{$objs}; $i++) {
		my $kegg = "";
		my $aliases = $self->database()->get_objects("cpdals",{COMPOUND=>$objs->[$i]->id(),type=>"KEGG"});
		for (my $j = 0; $j < @{$aliases}; $j++) {
			if (length($kegg) > 0) {
				$kegg .= "|";	
			}
			$kegg .= $aliases->[$j]->alias();
		}
		my $deltaG = "";
		my $deltaGErr = "";
		if (defined($objs->[$i]->deltaG()) && $objs->[$i]->deltaG() ne "10000000") {
			$deltaG = $objs->[$i]->deltaG();
			$deltaGErr = $objs->[$i]->deltaGErr();
		}
		my $charge = "";
		if (defined($objs->[$i]->charge()) && $objs->[$i]->charge() ne "10000000") {
			$charge = $objs->[$i]->charge();
		}
		my $line = $objs->[$i]->id()."\t".$objs->[$i]->name()."\t".$objs->[$i]->formula()."\t".$charge."\t".$deltaG."\t".$deltaGErr."\t".$objs->[$i]->mass()."\t".$kegg;
		push(@{$outputArray},$line);
	}
	$self->database()->print_array_to_file($directory."CompoundDatabase.txt",$outputArray);
}

=head3 ApplyStoichiometryCorrections

Definition:
	(string:Equation,string:Reverse equation,string:Full equation) = FIGMODEL->ApplyStoichiometryCorrections(string:Equation,string:Reverse equation,string:Full equation);
Description:

=cut

sub ApplyStoichiometryCorrections {
	my($self,$Equation,$ReverseEquation,$FullEquation) = @_;
	return ($Equation,$ReverseEquation,$FullEquation);
	my $CorrectionTable = $self->database()->GetDBTable("STOICH CORRECTIONS");
	if (defined($CorrectionTable)) {
		my $Row = $CorrectionTable->get_row_by_key($Equation,"OLD CODE");
		if (!defined($Row)) {
			$Row = $CorrectionTable->get_row_by_key($ReverseEquation,"OLD CODE");
			if (defined($Row)) {
				return ($Row->{"REVERSE CODE"}->[0],$Row->{"CODE"}->[0],$Row->{"REVERSE EQUATION"}->[0]);
			}
			return ($Equation,$ReverseEquation,$FullEquation);
		}
		return ($Row->{"CODE"}->[0],$Row->{"REVERSE CODE"}->[0],$Row->{"EQUATION"}->[0]);
	}
	return ($Equation,$ReverseEquation,$FullEquation);
}

=head3 AddStoichiometryCorrection

Definition:
	0/1 = FIGMODEL->AddStoichiometryCorrection(string:Reaction ID,string:New equation);
Description:

=cut

sub AddStoichiometryCorrection {
	my($self,$DataToCorrect,$ReplacementEquation) = @_;

	#Checking if this is a reaction ID
	my $OldEquation = $DataToCorrect;
	my $ReactionData;
	if ($DataToCorrect =~ m/(rxn\d\d\d\d\d)/) {
		$ReactionData = FIGMODELObject->load($self->{"reaction directory"}->[0].$1,"\t");
		if (!defined($ReactionData)) {
			print STDERR "FIGMODEL:AddStoichiometryCorrection: Could not find input reaction ID: ".$DataToCorrect."\n";
			return 0;
		}
		$DataToCorrect = $ReactionData->{"EQUATION"}->[0];
	}
	#Loading the current correction table
	my $CorrectionTable = $self->database()->GetDBTable("STOICH CORRECTIONS");
	if (!defined($CorrectionTable)) {
		$CorrectionTable = ModelSEED::FIGMODEL::FIGMODELTable->new(["OLD CODE","CODE","REVERSE CODE","EQUATION","REVERSE EQUATION"],$self->{"Reaction database directory"}->[0]."masterfiles/StoichiometryCorrections.txt",["OLD CODE"],";","",undef)
	}
	#Getting the code etc for the data to correct and the new equation
	my $Translation = LoadSeparateTranslationFiles($self->{"Translation directory"}->[0]."CpdToAll.txt","\t");
	(my $Direction,my $Code,my $ReverseCode,my $Equation,my $Compartment,my $Error) = $self->ConvertEquationToCode($DataToCorrect,$Translation);
	if ($Error != 1) {
		($Direction,my $NewCode,my $NewReverseCode,my $NewEquation,$Compartment,$Error) = $self->ConvertEquationToCode($ReplacementEquation,$Translation);
		my $ReverseNewEquation = $NewEquation;
		$ReverseNewEquation =~ s/(.+)\s(<=>|=>|<=)\s(.+)/$3 $2 $1/;
		if ($ReverseNewEquation =~ m/\s=>/) {
			$ReverseNewEquation =~ s/\s=>/ <=/;
		} elsif ($ReverseNewEquation =~ m/<=\s/) {
			$ReverseNewEquation =~ s/<=\s/=> /;
		}
		if ($Error != 1) {
			#First checking if a row already exists... if so, the row will be overwritten
			my $Row = $CorrectionTable->get_row_by_key($Code,"CODE");
			if (!defined($Row)) {
				my $Row = $CorrectionTable->get_row_by_key($ReverseCode,"CODE");
				if (defined($Row)) {
					$Row->{"CODE"}->[0] = $NewReverseCode;
					$Row->{"REVERSE CODE"}->[0] = $NewCode;
					$Row->{"EQUATION"}->[0] = $ReverseNewEquation;
					$Row->{"REVERSE EQUATION"}->[0] = $NewEquation;
				} else {
					$Row->{"CODE"}->[0] = $NewCode;
					$Row->{"REVERSE CODE"}->[0] = $NewReverseCode;
					$Row->{"EQUATION"}->[0] = $NewEquation;
					$Row->{"REVERSE EQUATION"}->[0] = $ReverseNewEquation;
					$Row->{"OLD CODE"}->[0] = $Code;
					$CorrectionTable->add_row($Row);
				}
			} else {
				$Row->{"CODE"}->[0] = $NewCode;
				$Row->{"REVERSE CODE"}->[0] = $NewReverseCode;
				$Row->{"EQUATION"}->[0] = $NewEquation;
				$Row->{"REVERSE EQUATION"}->[0] = $ReverseNewEquation;
			}
			$CorrectionTable->save();
			return 1;
		}
	}
	return 0;
}
=head3 ConvertToNeutralFormula

Definition:
	string:neutral formula = FIGMODEL->ConvertToNeutralFormula(string:original formula,string:charge);
Description:
	Adjusts the hydrogens in a formula until the compound is in neutral form

=cut
sub ConvertToNeutralFormula {
	my ($self,$NeutralFormula,$Charge) = @_;

	if (!defined($NeutralFormula)) {
		$NeutralFormula = "";
	} elsif ($NeutralFormula eq "H") {
		#Do nothing
	} elsif (defined($Charge) && $Charge ne "0") {
		my $CurrentH = 0;
		if ($NeutralFormula =~ m/H(\d+)/) {
			$CurrentH = $1;
		} elsif ($NeutralFormula =~ m/H[A-Z]/ || $NeutralFormula =~ m/H$/) {
			$CurrentH = 1;
		}
		my $NewH = $CurrentH;
		if ($Charge >= $CurrentH) {
			$NewH = 0;
		} else {
			$NewH = $CurrentH - $Charge;
		}
		my $Replace = "H";
		if ($NewH > 1) {
			$Replace = "H".$NewH;
		} elsif ($NewH == 0) {
			$Replace = "";
		}
		if ($CurrentH == 0 && $NewH > 0) {
			$NeutralFormula .= "H";
			if ($NewH > 1) {
				$NeutralFormula .= $NewH;
			}
		} elsif ($CurrentH == 1) {
			$NeutralFormula =~ s/H$/$Replace/;
			$NeutralFormula =~ s/H([A-Z])/$Replace$1/;
		} else {
			my $Match = "H".$CurrentH;
			$NeutralFormula =~ s/$Match/$Replace/;
		}
	}

	return $NeutralFormula;
}

=head3 rebuild_compound_database_table

Definition:
	void FIGMODEL->rebuild_compound_database_table();
Description:
	This function uses the compound files in the compounds directory to rebuild the table of compounds in the database

=cut
sub rebuild_compound_database_table {
	my ($self) = @_;

	#Processing all pending compound combinations
	if (-e $self->config("pending combination filename")->[0]) {
		my $Combinations = $self->database()->load_multiple_column_file($self->config("pending combination filename")->[0],";");
		for (my $i=0; $i < @{$Combinations}; $i++) {
			if (@{$Combinations->[$i]} >= 2) {
				my $CompoundOne = FIGMODELObject->load($self->config("compound directory")->[0].$Combinations->[$i]->[0],"\t");
				my $CompoundTwo = FIGMODELObject->load($self->config("compound directory")->[0].$Combinations->[$i]->[1],"\t");
				$CompoundOne->add_data($CompoundTwo->{"NAME"},"NAME",1);
				$CompoundOne->save();
			}
		}
		unlink($self->config("pending combination filename")->[0]);
	}
	
	#Backing up compound KEGG map
	system("cp ".$self->config("Translation directory")->[0]."CpdToKEGG.txt ".$self->config("Translation directory")->[0]."OldCpdToKEGG.txt");
	
	#Creating the compounds table
	my $tbl = $self->database()->create_table_prototype("COMPOUNDS");
	my @Files = glob($self->config("compound directory")->[0]."cpd*");
	my $obsoleteIDs;
	foreach my $Filename (@Files) {
		if ($Filename =~ m/(cpd\d\d\d\d\d)$/) {
			my $Data = FIGMODELObject->load($self->config("compound directory")->[0].$1,"\t");
			my @temp = @{$Data->{NAME}};
			delete $Data->{NAME};
			@{$Data->{NAME}} = $self->remove_duplicates(@temp);
			$Data->delete_key("CHANGES");
			$Data->save();
			
			#---Looking for a name match---#
			my $NewData = undef;
			if (!defined($Data->{"NAME"})) {
				$self->error_message("FIGMODEL:rebuild_compound_database_table:".$Data->{"DATABASE"}->[0]." had no names!");
				next;
			}
			
			#---First checking to see if a fullname match or search name match already exists in the DB---#
			foreach my $Name (@{$Data->{"NAME"}}) {
				$Name =~ s/;/-/;
				if (length($Name) > 0) {
					foreach my $SearchName ($self->ConvertToSearchNames($Name)) {
						if (length($SearchName) > 0) {
							push(@{$Data->{"SEARCHNAME"}},$SearchName);
						}
					}
				}
			}
			foreach my $SearchName (@{$Data->{"SEARCHNAME"}}) {
				$NewData = $tbl->get_row_by_key($SearchName,"SEARCHNAME");
				if (defined($NewData)) {
					last;
				}
			}

			#Adding the compound to the database table
			if (!defined($NewData)) {
				$tbl->add_row({DATABASE=>[$Data->{"DATABASE"}->[0]],NAME=>$Data->{"NAME"},SEARCHNAME=>$Data->{"SEARCHNAME"},FORMULA=>$Data->{"FORMULA"},CHARGE=>$Data->{"CHARGE"},STRINGCODE=>$Data->{"STRINGCODE"},MASS=>$Data->{"MASS"},DELTAG=>$Data->{"DELTAG"},DELTAGERR=>$Data->{"DELTAGERR"},ARGONNEID=>$Data->{"DATABASE"}});
			} else {
				my $originalObject = FIGMODELObject->load($self->config("compound directory")->[0].$NewData->{DATABASE}->[0],"\t");
				$originalObject->add_data($Data->{"NAME"},"NAME",1);
				$tbl->add_data($NewData,"NAME",$Data->{"NAME"}->[0],1);
				$tbl->add_data($NewData,"SEARCHNAME",$Data->{"SEARCHNAME"}->[0],1);
				if (!defined($NewData->{"FORMULA"}) && defined($Data->{"FORMULA"})) {
					my $formula = $Data->{"FORMULA"}->[0];
					if (defined($Data->{"CHARGE"})) {
						$formula = $self->ConvertToNeutralFormula($Data->{"FORMULA"}->[0],$Data->{"CHARGE"}->[0]);
					} 
					$tbl->add_data($NewData,"FORMULA",$formula,1);
					$originalObject->add_data([$formula],"FORMULA",1);
				}
				if (!defined($NewData->{"CHARGE"}) && defined($Data->{"CHARGE"})) {
					$tbl->add_data($NewData,"CHARGE",$Data->{"CHARGE"}->[0],1);
					$originalObject->add_data($Data->{"CHARGE"},"CHARGE",1);
				}
				if (!defined($NewData->{"STRINGCODE"}) && defined($Data->{"STRINGCODE"})) {
					$tbl->add_data($NewData,"STRINGCODE",$Data->{"STRINGCODE"}->[0],1);
					$originalObject->add_data($Data->{"STRINGCODE"},"STRINGCODE",1);
				}
				$Data->add_data(["This compound is now obselete replaced by equivalent compound ".$NewData->{"DATABASE"}->[0]."."],"CHANGES",1);
				$Data->add_headings(("CHANGES"));
				delete $Data->{"DBLINKS"};
				$Data->save();
				$originalObject->save();
				$obsoleteIDs->{$Data->{"DATABASE"}->[0]} = $NewData->{DATABASE}->[0];
				$tbl->add_data($NewData,"ARGONNEID",$Data->{"DATABASE"}->[0],1);
			}
		}
	}
	
	#Saving obsolete reaction file
	$self->database()->print_multicolumn_array_to_file($self->config("Translation directory")->[0]."ObsoleteCpdIDs.txt",$self->put_hash_in_two_column_array($obsoleteIDs,0),"\t");
	
	#Using the translation files to fill in the KEGG and model ID feilds of the database table
	@Files = glob($self->config("Translation directory")->[0]."CpdTo*");
	foreach my $Filename (@Files) {
		if ($Filename =~ m/CpdTo(.+)\.txt/) {
			my $db = $1;
			(my $dummyTwo,my $translationTwo) = $self->put_two_column_array_in_hash($self->database()->load_multiple_column_file($Filename,"\t"));
			my @foreignIDs = keys(%{$translationTwo});
			print "Now processing ".$db."\n";
			foreach my $id (@foreignIDs) {
				my $NewData = $tbl->get_row_by_key($translationTwo->{$id},"ARGONNEID");
				if (!defined($NewData)) {
					$self->error_message("FIGMODEL:rebuild_compound_database_table:Compound ".$translationTwo->{$id}." not found.");
					next;
				}
				#Ensuring that the IDs in these translation files are not obsolete
				if ($translationTwo->{$id} ne $NewData->{DATABASE}->[0]) {
					print "change\n";
				}
				$translationTwo->{$id} = $NewData->{DATABASE}->[0];
				#Adding foreign IDs to the reactions database table
				if ($db eq "KEGG") {
					push(@{$NewData->{KEGGID}},$id);
				} else {
					$tbl->add_data($NewData,"MODELID",$id,1);
					push(@{$NewData->{MODELS}},$db.":".$id);
				}
			}
			#Saving the altered translation files
			$self->database()->print_multicolumn_array_to_file($Filename,$self->put_hash_in_two_column_array($translationTwo,0),"\t");
		}
	}
	
	#Using the KEGG map data table to populate the KEGG map column
	my $mapTbl = $self->database()->get_table("KEGGMAPDATA");
	for (my $i=0; $i < $mapTbl->size(); $i++) {
		my $row = $mapTbl->get_row($i);
		if (defined($row->{COMPOUNDS})) {
			for (my $j=0; $j < @{$row->{COMPOUNDS}}; $j++) {
				my $NewData = $tbl->get_row_by_key($row->{COMPOUNDS}->[$j],"ARGONNEID");
				if (defined($NewData)) {
					$row->{COMPOUNDS}->[$j] = $NewData->{DATABASE}->[0];
					push(@{$NewData->{"KEGG MAPS"}},$row->{ID}->[0]);
				}
			}
		}
	}
	$mapTbl->save();
	
	#Saving the reaction database table
	$tbl->save();
}

=head3 rebuild_reaction_database_table

Definition:
	void FIGMODEL->rebuild_reaction_database_table();
Description:
	This function uses the reaction files in the reactions directory to rebuild the table of reactions in the database

=cut
sub rebuild_reaction_database_table {
	my ($self) = @_;
	
	my $tbl = $self->database()->create_table_prototype("REACTIONS");
	my $biomassTbl = $self->database()->create_table_prototype("BIOMASS");
	my @Files = glob($self->config("reaction directory")->[0]."rxn*");
	push(@Files,glob($self->config("reaction directory")->[0]."bio*"));
	(my $dummy,my $translation) = $self->put_two_column_array_in_hash($self->database()->load_multiple_column_file($self->config("Translation directory")->[0]."ObsoleteCpdIDs.txt","\t"));
	my $obsoleteIDs;
	foreach my $Filename (@Files) {
		if ($Filename =~ m/(rxn\d\d\d\d\d)$/ || $Filename =~ m/(bio\d\d\d\d\d)$/) {
			my $Data = FIGMODELObject->load($self->{"reaction directory"}->[0].$1,"\t");
			$Data->delete_key("CHANGES");
			$Data->save();
			#---Looking for an equation match---#
			my $NewData = undef;
			if (!defined($Data->{"EQUATION"})) {
				$self->error_message("FIGMODEL:rebuild_reaction_database_table:".$Data->{"DATABASE"}->[0]." had no equation!");
				next;
			}
			(my $Direction,my $Code,my $ReverseCode,my $FullEquation,my $NewCompartment,my $Error) = $self->ConvertEquationToCode($Data->{"EQUATION"}->[0],$translation);
			if ($Error == 1) {
				#If the reaction involves a compound not found in the compound database, then something is wrong and this reaction should not be in the reaction database
				$self->error_message("FIGMODEL:rebuild_reaction_database_table:Error in ".$Data->{"DATABASE"}->[0]." equation: ".$FullEquation);
				next;
			}
			#Checking if the reaction is involved in a forced mapping and if so, the equation is replaced with the forced mapping equation:
			#($Code,$ReverseCode,$FullEquation) = $self->ApplyStoichiometryCorrections($Code,$ReverseCode,$FullEquation);
			#Checking if the reaction is already in the database
			if ($Filename =~ m/(rxn\d\d\d\d\d)$/) {
				$NewData = $tbl->get_row_by_key($Code,"CODE");
				my $suffix = "";
				if (!defined($NewData)) {
					$suffix = "r";
					$NewData = $tbl->get_row_by_key($ReverseCode,"CODE");
				}
				#Adding the reaction to the database table
				if (!defined($NewData)) {
					$tbl->add_row({DATABASE=>[$Data->{"DATABASE"}->[0]],NAME=>$Data->{"NAME"},EQUATION=>[$FullEquation],CODE=>[$Code],"MAIN EQUATION"=>$Data->{"MAIN EQUATION"},ENZYME=>$Data->{"ENZYME"},PATHWAY=>$Data->{"PATHWAY"},REVERSIBILITY=>$Data->{"THERMODYNAMIC REVERSIBILITY"},DELTAG=>$Data->{"DELTAG"},DELTAGERR=>$Data->{"DELTAGERR"},ARGONNEID=>[$Data->{"DATABASE"}->[0]]});
				} else {
					$obsoleteIDs->{$Data->{"DATABASE"}->[0].$suffix} = $NewData->{DATABASE}->[0];
					$tbl->add_data($NewData,"ARGONNEID",$Data->{"DATABASE"}->[0])
				}
			} else {
				$NewData = $tbl->get_row_by_key($FullEquation,"EQUATION");
				#Adding the reaction to the database table
				if (!defined($NewData)) {
					$biomassTbl->add_row({DATABASE=>[$Data->{"DATABASE"}->[0]],NAME=>$Data->{"NAME"},EQUATION=>[$FullEquation],OBSOLETEID=>[$Data->{"DATABASE"}->[0]],SOURCE=>$Data->{SOURCE},USER=>$Data->{USER},"ESSENTIAL REACTIONS"=>$Data->{"ESSENTIAL REACTIONS"}});
				} else {
					$obsoleteIDs->{$Data->{"DATABASE"}->[0]} = $NewData->{DATABASE}->[0];
					$biomassTbl->add_data($NewData,"OBSOLETEID",$Data->{"DATABASE"}->[0])
				}
			}
		}
	}
	
	#Saving obsolete reaction file
	$self->database()->print_multicolumn_array_to_file($self->config("Translation directory")->[0]."ObsoleteRxnIDs.txt",$self->put_hash_in_two_column_array($obsoleteIDs,0),"\t");
	
	#Using the translation files to fill in the KEGG and model ID feilds of the database table
	@Files = glob($self->config("Translation directory")->[0]."RxnTo*");
	foreach my $Filename (@Files) {
		if ($Filename =~ m/RxnTo(.+)\.txt/) {
			my $db = $1;
			(my $dummyTwo,my $translationTwo) = $self->put_two_column_array_in_hash($self->database()->load_multiple_column_file($Filename,"\t"));
			my @foreignIDs = keys(%{$translationTwo});
			print "Now processing ".$db."\n";
			foreach my $id (@foreignIDs) {
				my $NewData = $tbl->get_row_by_key($translationTwo->{$id},"ARGONNEID");
				if (!defined($NewData)) {
					$self->error_message("FIGMODEL:rebuild_reaction_database_table:Reaction ".$translationTwo->{$id}." not found.");
					next;
				}
				#Ensuring that the IDs in these translation files are not obsolete
				if ($translationTwo->{$id} ne $NewData->{DATABASE}->[0]) {
					print "change\n";
				}
				$translationTwo->{$id} = $NewData->{DATABASE}->[0];
				#Adding foreign IDs to the reactions database table
				if ($db eq "KEGG") {
					push(@{$NewData->{KEGGID}},$id);
				} else {
					$tbl->add_data($NewData,"MODELID",$id,1);
					push(@{$NewData->{MODELS}},$db.":".$id);
				}
			}
			#Saving the altered translation files
			$self->database()->print_multicolumn_array_to_file($Filename,$self->put_hash_in_two_column_array($translationTwo,0),"\t");
		}
	}
	
	#Using the KEGG map data table to populate the KEGG map column
	my $mapTbl = $self->database()->get_table("KEGGMAPDATA");
	for (my $i=0; $i < $mapTbl->size(); $i++) {
		my $row = $mapTbl->get_row($i);
		if (defined($row->{REACTIONS})) {
			for (my $j=0; $j < @{$row->{REACTIONS}}; $j++) {
				my $NewData = $tbl->get_row_by_key($row->{REACTIONS}->[$j],"ARGONNEID");
				if (defined($NewData)) {
					$row->{REACTIONS}->[$j] = $NewData->{DATABASE}->[0];
					push(@{$NewData->{"KEGG MAPS"}},$row->{ID}->[0]);
				}
			}
		}
	}
	$mapTbl->save();
	
	#Saving the reaction database table
	$tbl->save();
	$biomassTbl->save();
	
	#Removing obsolete reactions from database models
	for (my $i=0; $i < $self->number_of_models(); $i++) {
		my $model = $self->get_model($i);
		$model->remove_obsolete_reactions();
	}
}

=head3 distribute_bomass_data_to_biomass_files

Definition:
	void FIGMODEL->distribute_bomass_data_to_biomass_files();
Description:
	This function distributes the essential reactions and user data from the biomass table to the biomass files

=cut
sub distribute_bomass_data_to_biomass_files {
	my ($self) = @_;
	
	my $tbl = $self->database()->get_table("BIOMASS");
	for (my $i = 0; $i < $tbl->size(); $i++) {
		my $row = $tbl->get_row($i);
		my $Data = FIGMODELObject->load($self->{"reaction directory"}->[0].$row->{DATABASE}->[0],"\t");
		$Data->{"ESSENTIAL REACTIONS"} = $row->{"ESSENTIAL REACTIONS"};
		$Data->{"USER"} = $row->{"USER"};
		$Data->{"SOURCE"} = $row->{"SOURCE"};
		$Data->add_headings(("ESSENTIAL REACTIONS","USER","SOURCE"));
		$Data->save();
	}
}

=head2 Model related methods

=head3 import_model_file
Definition:
	Output:{} FIGMODEL->import_model_file({
		baseid => $args->{"name"},
		genome => $args->{"genome"},
		filename => $args->{"filename"},
		biomassFile => $args->{"biomassFile"},
		owner => $args->{"owner"},
		public => $args->{"public"},
		overwrite => $args->{"overwrite"},
		provenance => $args->{"provenance"},
		autoCompleteMedia => $args->{"autoCompleteMedia"}
	});
Description:
	Imports the specified model file into the database adding reactions and compounds if necessary and creating all necessary database links
=cut
sub import_model_file {
	my ($self,$args) = @_;
	$args = $self->process_arguments($args,["id","genome"],{
		filename => undef,
		biomassFile => undef,
		owner => $args->{"owner"},
		public => $args->{"public"},
		overwrite => $args->{"overwrite"},
		provenance => $args->{"provenance"},
		autoCompleteMedia => $args->{"autoCompleteMedia"}
	});
	if (!defined($args->{filename})) {
		$args->{filename} = $self->ws()->directory().$args->{id}.".mdl";
	}
	if (!-e $args->{filename}) {
		ModelSEED::globals::ERROR("Could not find model specification file: ".$args->{filename}."!");		
	}
	#Calculating the full ID of the model
	if ($args->{id} =~ m/(Seed\d+\.\d+.*)\.\d+$/) {
		$args->{id} = $1;
	} elsif ($args->{id} =~ m/^(.+)\.(\d+)$/) {
		$args->{id} = $1;
	}
	if ($args->{owner} ne "master") {
		my $usr = $self->database()->get_object("user",{login=>$args->{owner}});
		ModelSEED::globals::ERROR("invalid model owner: ".$args->{owner}) if (!defined($usr));
		$args->{id} .= ".".$usr->_id();
	}
	#Checking if the model exists, and if not, creating the model
	my $mdl;
	my $modelObj = $self->database()->sudo_get_object("model",{id => $args->{id}});
	if (!defined($modelObj)) {
		$mdl = $self->create_model({
			id => $args->{id},
			owner => $args->{owner},
			genome => $args->{genome},
			gapfilling => 0,
			runPreliminaryReconstruction => 0,
			biochemSource => $args->{biochemSource},
			autoCompleteMedia => $args->{autoCompleteMedia}
		});
		$modelObj = $mdl->ppo();
	} elsif ($args->{overwrite} == 0) {
		ModelSEED::globals::ERROR($args->{id}." already exists and overwrite request was not provided. Import halted.".$args->{owner});
	} else {
		my $rights = $self->database()->get_object_rights($modelObj,"model");
		if (!defined($rights->{admin})) {
			ModelSEED::globals::ERROR("No rights to alter model object");
		}
	}
	$mdl = $self->get_model($args->{id});
	if (!-defined($mdl)) {
		ModelSEED::globals::ERROR("Could not load/create model ".$mdl."!");
	}
	#Clearing current model data in the database
	if (defined($args->{id}) && length($args->{id}) > 0 && defined($mdl)) {
		my $objs = $mdl->figmodel()->database()->get_objects("rxnmdl",{MODEL => $args->{id}});
		for (my $i=0; $i < @{$objs}; $i++) {
			$objs->[$i]->delete();	
		}
	}
	my $rxnmdl = ModelSEED::FIGMODEL::FIGMODELTable::load_table($args->{filename},"[;\\t]","|",1,["LOAD"]);
	my $biomassID;
	for (my $i=0; $i < $rxnmdl->size();$i++) {
		my $row = $rxnmdl->get_row($i);
		if ($row->{LOAD}->[0] =~ m/(bio\d+)/) {
			$biomassID = $1;
		}
		my $rxnObj = $self->database()->get_object("rxnmdl",{
			REACTION => $row->{LOAD}->[0],
			MODEL => $args->{id},
			compartment => $row->{COMPARTMENT}->[0]
		});
		if (!defined($rxnObj)) {
			$self->database()->create_object("rxnmdl",{
				REACTION => $row->{LOAD}->[0],
				MODEL => $args->{id},
				directionality => $row->{DIRECTIONALITY}->[0],
				compartment => $row->{COMPARTMENT}->[0],
				pegs => join("|",@{$row->{"ASSOCIATED PEG"}}),
				confidence => $row->{CONFIDENCE}->[0],
				notes => $row->{NOTES}->[0],
				reference => $row->{REFERENCE}->[0]
			});
		} else {
			if ($rxnObj->directionality() ne $row->{DIRECTIONALITY}->[0]) {
				$rxnObj->directionality("<=>");
			}
			#$rxnObj->pegs($rxnObj->pegs()."|".join("|",@{$row->{"ASSOCIATED PEG"}}));
		}
	}
	#Loading biomass reaction file
	if (!defined($args->{biomassFile}) && defined($biomassID)) {
		$args->{biomassFile} = $self->ws()->directory().$biomassID.".bof";
	}
	if (!-e $args->{biomassFile}) {
		ModelSEED::globals::WARNING("Could not find biomass specification file: ".$args->{biomassFile}."!");	
	}else{
	    my $obj = ModelSEED::FIGMODEL::FIGMODELObject->new({filename=>$args->{biomassFile},delimiter=>"\t",-load => 1});
	    my $bofobj = $self->get_reaction()->add_biomass_reaction_from_equation({
		equation => $obj->{EQUATION}->[0],
		biomassID => $obj->{DATABASE}->[0]
	        });
	    $modelObj->biomassReaction($obj->{DATABASE}->[0]);
	}
	return $modelObj;
}
=head3 import_model
Definition:
	Output:{} FIGMODEL->import_model({
		path => ?:location where import files are located
		baseid => ?:proposed ID for model noting that user suffix will be added if user is not "master"
		owner => FIGMODEL->user():user who will own the model
		public => 0:0/1 indicating if model is public
		overwrite => 0:indicates that an existing model will be overwritten if found
	});
	
	
Description:
	Imports the specified model file into the database adding reactions and compounds if necessary and creating all necessary database links
=cut
sub import_model {
	my ($self,$args) = @_;
	$args = $self->process_arguments($args,["baseid"],{
		path => $self->ws()->directory(),
		owner => $self->user(),
		genome => "NONE",
		public => 0,
		overwrite => 0,
		biochemSource => undef 
	});
	return $self->new_error_message({function => "import_model",args => $args}) if (defined($args->{error}));
	my $result = {success => 1};

	#Calculating the full ID of the model
	my $id = $args->{baseid};
	if ($args->{owner} ne "master") {
		my $usr = $self->database()->get_object("user",{login=>$args->{owner}});
		return $self->new_error_message({message=> "invalid model owner: ".$args->{owner},function => "import_model",args => $args}) if (!defined($usr));
		$id .= ".".$usr->_id();
	}

	my $print_output=$self->ws()->directory()."mdl-importmodel_Output_".$id;
	my $oldout;
	print "Output printed to ",$print_output,"\n";
	open($oldout, ">&STDOUT") or warn "Can't dup STDOUT: $!";
	open(STDOUT, '>', $print_output) or warn "Can't redirect STDOUT: $!";
	select STDOUT; $| = 1;

	#Checking if the model exists, and if not, creating the model
	my $mdl;
	my $modelObj = $self->database()->get_object("model",{id => $id});
	if (!defined($modelObj)) {
		$mdl = $self->create_model({
			id => $id,
			owner => $args->{owner},
			genome => $args->{genome},
			gapfilling => 0,
			runPreliminaryReconstruction => 0,
			biochemSource => $args->{biochemSource}
		});
	} elsif ($args->{overwrite} == 0) {
		return $self->new_error_message({message=> $id." already exists and overwrite request was not provided. Import halted.".$args->{owner},function => "import_model",args => $args});
	}else{
	    $mdl = $self->get_model($id);
		$mdl->GenerateModelProvenance({
		    biochemSource => $args->{biochemSource}
		});	
	}
	my $importTables = ["reaction","compound","cpdals","rxnals"];
	my %CompoundAlias=();
	if (defined($id) && length($id) > 0 && defined($mdl)) {
		for (my $i=0; $i < @{$importTables}; $i++) {
			$mdl->figmodel()->database()->freezeFileSyncing($importTables->[$i]);
		}
		my $objs = $mdl->figmodel()->database()->get_objects("rxnmdl",{MODEL => $id});
		for (my $i=0; $i < @{$objs}; $i++) {
			$objs->[$i]->delete();	
		}
	}
	#Loading the compound table
	my $translation;
	if (!-e $args->{path}.$args->{baseid}."-compounds.tbl") {
		return $self->new_error_message({
			message=> "could not find import file:".$args->{path}.$args->{baseid}."-compounds.tbl",
			function => "import_model",
			args => $args } )
	}
	my $tbl = ModelSEED::FIGMODEL::FIGMODELTable::load_table($args->{path}.$args->{baseid}."-compounds.tbl","\t","|",0,["ID"]);
	for (my $i=0; $i < $tbl->size();$i++) {
		my $row = $tbl->get_row($i);
		if (!defined($row->{"NAMES"}) || !defined($row->{"ID"})) {
			next;
		}
		#Finding if existing compound shares search name
		my $cpd;
		my $newStrings=();
		foreach my $stringcode ( @{$row->{"STRINGCODE"}} ){
		    my $cpdals = $mdl->figmodel()->database()->get_object("cpdals",{alias => $stringcode,type => "stringcode%"});
		    if (defined($cpdals) && !defined($cpd)) {
			$cpd =  $mdl->figmodel()->database()->get_object("compound",{id => $cpdals->COMPOUND()});
			print "Found using InChI string: ",$cpd->id()," for id ",$row->{ID}->[0],"\n";
		    }
		    if(!defined($cpdals)){
			$newStrings->{$stringcode}=1;
		    }
		}

		my $newNames=();
		for (my $j=0; $j < @{$row->{"NAMES"}}; $j++) {
		    if (length($row->{"NAMES"}->[$j]) > 0) {
			my $searchNames = [$self->get_compound()->convert_to_search_name($row->{"NAMES"}->[$j])];
			for (my $k=0; $k < @{$searchNames}; $k++) {
			    #Look for searchname in original 'searchname' type
			    my $cpdals = $mdl->figmodel()->database()->get_object("cpdals",{alias => $searchNames->[$k],type => "searchname"});
			    
			    #if not, look for it in previous imports
			    if (!defined($cpdals)) {
				my $cpdalss = $mdl->figmodel()->database()->get_objects("cpdals",{alias => $searchNames->[$k],type=>"searchname%"});
				for (my $m = 0; $m < @{$cpdalss}; $m++) {
				    $cpdals = $cpdalss->[$m];
				    last;
				}
			    }
			    if (defined($cpdals)) {
				if (!defined($cpd)) {
				    $cpd = $mdl->figmodel()->database()->get_object("compound",{id => $cpdals->COMPOUND()});
				    print "Found using name (",$row->{"NAMES"}->[$j],"): ",$cpd->id()," for id ",$row->{ID}->[0],"\n";
				}
			    } else {
				#prevent use of names that being with cpd, for obvious confusion
				#with ModelSEED identifiers
				next if substr($searchNames->[$k],0,3) eq "cpd";
				
				#stopgap to prevent names being inserted that are too close
				#this occurs because the database doesn't recognize upper/lower case when
				#using indexes
				if(!exists($newNames->{search}->{$searchNames->[$k]})){
				    $newNames->{name}->{$row->{"NAMES"}->[$j]} = 1;
				}
				$newNames->{search}->{$searchNames->[$k]} = 1;
				
			    }
			}
		    }
		}
		if (!defined($cpd) && defined($row->{"KEGG"}->[0])) {
			my $cpdals = $mdl->figmodel()->database()->get_object("cpdals",{alias => $row->{"KEGG"}->[0],type => "KEGG%"});
			if (defined($cpdals)) {
				$cpd = 	$mdl->figmodel()->database()->get_object("compound",{id => $cpdals->COMPOUND()});
				print "Found using KEGG (",$row->{"KEGG"}->[0],"): ",$cpd->id()," for id ",$row->{ID}->[0],"\n";
			}
		}
		if (!defined($cpd) && defined($row->{"METACYC"}->[0])) {
			my $cpdals = $mdl->figmodel()->database()->get_object("cpdals",{alias => $row->{"MetaCyc"}->[0],type => "MetaCyc%"});
			if (defined($cpdals)) {
			    $cpd = $mdl->figmodel()->database()->get_object("compound",{id => $cpdals->COMPOUND()});
			    print "Found using MetaCyc (",$row->{"METACYC"}->[0],"): ",$cpd->id()," for id ",$row->{ID}->[0],"\n";
			}
		}

		#If a matching compound was found, we handle this scenario
		if (defined($cpd)) {
			if (defined($row->{"CHARGE"}->[0])){
			    if ($cpd->charge() == 10000000){
				$cpd->charge($row->{"CHARGE"}->[0]);
			    }
			}
			if (defined($row->{"MASS"}->[0])){
			    if ($cpd->mass() == 10000000){
				$cpd->mass($row->{"MASS"}->[0]);
			    }
			}
			if (defined($row->{"FORMULA"}->[0])){
			    if (!defined($cpd->formula()) || length($cpd->formula()) == 0) {
				$cpd->formula($row->{"FORMULA"}->[0]);
			    }
			}
		} else {
		    my $newid = $mdl->figmodel()->get_compound()->get_new_temp_id();
		    print "New:".$newid." for ".$row->{"ID"}->[0]."\t",$row->{"NAMES"}->[0],"\n";
		    if (!defined($row->{"MASS"}->[0]) || $row->{"MASS"}->[0] eq "") {
			$row->{"MASS"}->[0] = 10000000;	
		    }
		    if (!defined($row->{"CHARGE"}->[0]) || $row->{"CHARGE"}->[0] eq "") {
			$row->{"CHARGE"}->[0] = 10000000;	
		    }
		    if (!defined($row->{"ABBREV"}->[0]) || $row->{"ABBREV"}->[0] eq "") {
			$row->{"ABBREV"}->[0] = $row->{"NAMES"}->[0];	
		    }
		    $cpd = $mdl->figmodel()->database()->create_object("compound",{
			id => $newid,
			name => $row->{"NAMES"}->[0],
			abbrev => $row->{"ABBREV"}->[0],
			mass => $row->{"MASS"}->[0],
			charge => $row->{"CHARGE"}->[0],
			deltaG => 10000000,
			deltaGErr => 10000000,
			owner => $args->{owner},
			modificationDate => time(),
			creationDate => time(),
			public => 1,
			scope => $id
			});
		}
		foreach my $name ( grep { $_ ne $row->{"ID"}->[0] } keys(%{$newNames->{name}})) {
		    $mdl->figmodel()->database()->create_object("cpdals",{COMPOUND => $cpd->id(), type => "name".$id, alias => $name});
		}
		foreach my $name ( grep { $_ ne $row->{"ID"}->[0] } keys(%{$newNames->{search}})) {
		    $mdl->figmodel()->database()->create_object("cpdals",{COMPOUND => $cpd->id(), type => "searchname".$id, alias => $name});
		}
		foreach my $stringcode ( keys %$newStrings ){
		    $mdl->figmodel()->database()->create_object("cpdals",{COMPOUND => $cpd->id(), type => "stringcode".$id, alias => $stringcode});
		}

		print $cpd->id(),"\t",$id,"\t",$row->{"ID"}->[0],"\n";
		$mdl->figmodel()->database()->create_object("cpdals",{COMPOUND => $cpd->id(), type => $id, alias => $row->{"ID"}->[0]});

		$translation->{$row->{"ID"}->[0]} = $cpd->id();
	}

	#Loading the reaction table
	return $self->new_error_message({message=> "could not find import file:".$args->{path}.$args->{baseid}."-reactions.tbl",function => "import_model",args => $args}) if (!-e $args->{path}.$args->{baseid}."-reactions.tbl");
	$tbl = ModelSEED::FIGMODEL::FIGMODELTable::load_table($args->{path}.$args->{baseid}."-reactions.tbl","\t","|",0,["ID"]);
	for (my $i=0; $i < $tbl->size();$i++) {
		my $row = $tbl->get_row($i);
		if (!defined($row->{"EQUATION"}->[0])) {
			next;	
		}
		if (!defined($row->{"REFERENCE"})) {
			$row->{"REFERENCE"}->[0] = "NONE";
		}
		if (!defined($row->{"COMPARTMENT"}->[0])) {
			$row->{"COMPARTMENT"}->[0] = "c";
		}
		if (!defined($row->{"CONFIDENCE"}->[0])) {
			$row->{"CONFIDENCE"}->[0] = "-1";
		}
		if (!defined($row->{"REFERENCE"}->[0])) {
			$row->{"REFERENCE"}->[0] = "NONE";
		}
		if (!defined($row->{"NOTES"}->[0])) {
			$row->{"NOTES"}->[0] = "NONE";
		}
		if (!defined($row->{"PEGS"}->[0])) {
			$row->{"PEGS"}->[0] = "UNKNOWN";
		}
		if (!defined($row->{"NAMES"}->[0])) {
			$row->{"NAMES"}->[0] = $row->{"ID"}->[0];
		}
		if (!defined($row->{"ABBREV"}->[0])) {
			$row->{"ABBREV"}->[0] = $row->{"ID"}->[0];
		}
		if (!defined($row->{"ENZYMES"})) {
			$row->{"ENZYMES"} = [];
		}

		#Checking if there is an equation match
		my $codeResults = $self->get_reaction()->createReactionCode({equation => $row->{"EQUATION"}->[0],translations => $translation});
		if (defined($codeResults->{error})) {
			delete $args->{error};
			$self->new_error_message({message=> "Error mapping reaction for ".$row->{"ID"}->[0].":".$row->{"EQUATION"}->[0]."\tResulting Equation: ".$codeResults->{fullEquation}."\tResulting Error: ".$codeResults->{error},function => "import_model",args => $args});
			next;
		}
		#Checking if this is a biomass reaction
		if ($codeResults->{code} =~ m/cpd11416/) {
			my $newid;
			if (defined($mdl->biomassReaction()) && length($mdl->biomassReaction()) > 0 && lc($mdl->biomassReaction()) ne "none") {
			    print $mdl->biomassReaction(),"mdl\n";
				$newid = $mdl->biomassReaction();
			}
			my $bofobj = $self->get_reaction()->add_biomass_reaction_from_equation({
				equation => $codeResults->{fullEquation},
				biomassID => $newid
			});
			$newid = $bofobj->id();
			if ($mdl->ppo()->public() == 0 && $mdl->ppo()->owner() ne "master") {
				$self->database()->change_permissions({
					objectID => $newid,
					permission => "admin",
					user => $mdl->ppo()->owner(),
					type => "bof"
				});
				$bofobj->public(0);
				$bofobj->owner($mdl->ppo()->owner());
			}
			$mdl->biomassReaction($bofobj->id());			
			$translation->{$row->{"ID"}->[0]} = $bofobj->id();
			print "Created Biomass Reaction:".$newid." for ".$row->{"ID"}->[0]."\t".$codeResults->{fullEquation}."\n";
			next;
		}
		if (!defined($row->{"DIRECTIONALITY"}->[0])) {
			$row->{"DIRECTIONALITY"}->[0] = $codeResults->{direction};
		}
		if (defined($codeResults->{compartment}) && $codeResults->{compartment} ne "c") {
			$row->{"COMPARTMENT"}->[0] = $codeResults->{compartment};
		}
		if ($row->{"COMPARTMENT"}->[0] =~ m/\[(.)\]/) {
			$row->{"COMPARTMENT"}->[0] = $1;
		}
		my $prior_eqn=$codeResults->{code};

		($codeResults->{code},$codeResults->{reverseCode},$codeResults->{fullEquation}) = $self->ApplyStoichiometryCorrections($codeResults->{code},$codeResults->{reverseCode},$codeResults->{fullEquation});

		my $rxn = $mdl->figmodel()->database()->get_object("reaction",{code => $codeResults->{code}});
		if (!defined($rxn)) {
			$rxn = $mdl->figmodel()->database()->get_object("reaction",{code => $codeResults->{reverseCode}});
			if (defined($rxn)) {
				if ($row->{"DIRECTIONALITY"}->[0] eq "=>") {
					$row->{"DIRECTIONALITY"}->[0] = "<=";
				} elsif ($row->{"DIRECTIONALITY"}->[0] eq "<=") {
					$row->{"DIRECTIONALITY"}->[0] = "=>";
				}
			}
		}
		if (defined($rxn)) {
			print "Found:".$rxn->id()." for ".$row->{"ID"}->[0]."\n";
			if ($row->{"DIRECTIONALITY"}->[0] ne $rxn->reversibility() && $rxn->reversibility() ne "<=>") {
				$rxn->reversibility("<=>");
			}
			if (defined($row->{"ENZYMES"}->[0])) {
				my $enzymeHash;
				for (my $j=0; $j < @{$row->{"ENZYMES"}}; $j++) {
					if ($row->{"ENZYMES"}->[$j] =~ m/[^.]+\.[^.]+\.[^.]+\.[^.]+/) {
						$enzymeHash->{$row->{"ENZYMES"}->[$j]} = 1;
					}
				}
				if (defined($rxn->enzyme()) && length($rxn->enzyme()) > 0) {
					my $list = [split(/\|/,$rxn->enzyme())];
					for (my $j=0; $j < @{$list}; $j++) {
						if ($list->[$j] =~ m/[^.]+\.[^.]+\.[^.]+\.[^.]+/) {
							$enzymeHash->{$list->[$j]} = 1;
						}
					}
				}
				my $newString = join("|",sort(keys(%{$enzymeHash})));
				if ($newString ne $rxn->enzyme()) {
					$rxn->enzyme($newString);
				}
			}
		} else {
			my $newid = $mdl->figmodel()->get_reaction()->get_new_temp_id();
			print "New:".$newid." for ".$row->{"ID"}->[0]." with code: ".$codeResults->{code}."\n";
			$rxn = $mdl->figmodel()->database()->create_object("reaction",{
				id => $newid,
				name => $row->{"NAMES"}->[0],
				abbrev => $row->{"ABBREV"}->[0],
				enzyme => join("|",@{$row->{"ENZYMES"}}),
				code => $codeResults->{code},
				equation => $codeResults->{fullEquation},
				definition => $row->{"EQUATION"}->[0],
				deltaG => 10000000,
				deltaGErr => 10000000,
				reversibility => $row->{"DIRECTIONALITY"}->[0],
				thermoReversibility => "<=>",
				owner => $args->{owner},
				modificationDate => time(),
				creationDate => time(),
				public => 1,
				status => "UNKNOWN",
				scope => $id
			});
		}
		$mdl->figmodel()->database()->create_object("rxnals",{
			REACTION => $rxn->id(),
			type => $id,
			alias => $row->{"ID"}->[0]
		});
		$translation->{$row->{"ID"}->[0]} = $rxn->id();
		my $rxnmdl = $mdl->figmodel()->database()->get_object("rxnmdl",{
			MODEL => $id,
			REACTION => $rxn->id(),
			compartment => $row->{"COMPARTMENT"}->[0]
		});

		if (defined($rxnmdl)) {
		    print "Duplicate found for reaction ",$rxnmdl->REACTION()," for model ",$rxnmdl->MODEL(),"\n";
			if ($rxnmdl->directionality() ne $row->{"DIRECTIONALITY"}->[0]) {
				$rxnmdl->directionality("<=>");
			}
			if ($row->{"PEGS"}->[0] ne "UNKNOWN") {
				my $newPegs = join("|",@{$row->{"PEGS"}});
				if ($rxnmdl->pegs() ne "UNKNOWN") {
					$newPegs = $rxnmdl->pegs()."|".$newPegs;
				}
				$rxnmdl->pegs($newPegs);
			}
			if ($row->{"REFERENCE"}->[0] ne "NONE") {
				my $newRef = join("|",@{$row->{"REFERENCE"}});
				if ($rxnmdl->reference() ne "NONE") {
					$newRef = 	$rxnmdl->reference()."|".$newRef;
				}
				$rxnmdl->reference($newRef);
			}
			if ($row->{"NOTES"}->[0] ne "NONE") {
				my $newNotes = join("|",@{$row->{"NOTES"}});
				if ($rxnmdl->notes() ne "NONE") {
					$newNotes = 	$rxnmdl->notes()."|".$newNotes;
				}
				$rxnmdl->notes($newNotes);
			}
		} else {
			$mdl->figmodel()->database()->create_object("rxnmdl",{
				MODEL => $id,
				REACTION => $rxn->id(),
				pegs => join("|",@{$row->{"PEGS"}}),
				compartment => $row->{"COMPARTMENT"}->[0],
				directionality => $row->{"DIRECTIONALITY"}->[0],
				confidence => $row->{"CONFIDENCE"}->[0],
				reference => join("|",@{$row->{"REFERENCE"}}),
				notes => join("|",@{$row->{"NOTES"}})
			});
		}
	}

	for (my $i=0; $i < @{$importTables}; $i++) {
		$mdl->figmodel()->database()->unfreezeFileSyncing($importTables->[$i]);
	}
	$mdl->processModel();

	#restore STDOUT
	open(STDOUT, ">&", $oldout) or warn "Can't dup \$oldout: $!";

	print "The model has been successfully imported as \"",$id,"\"\n";

	return $result;
}

=head3 GetTransportReactionsForCompoundIDList
Definition:
	my $TransportDataHash = $model->GetTransportReactions($CompoundIDListRef);
Description:
	This function accepts as an argument a reference to an array of compound IDs, and it returns a reference to a hash of hashes.
	The first key in the hash of hashes is the compound ID, and the second key is the reaction ID of a transporter for the compound.
	Note that often a single compound ID will have multiple transport reactions in the database.
	The equation for the transport reactions are stored in the hash of hashes like so:
Example:
	my $model = FIGMODEL->new();
	$CompoundIDListRef = ["cpd00001","cpd00002"];
	my $TransportDataHash = $model->GetTransportReactions($CompoundIDListRef);
	my @TransportReactionIDList = keys(%{$TransportDataHash->{$CompoundIDListRef->[$i]}}));
	my $TransportReactionEquation = $TransportDataHash->{$CompoundIDListRef->[$i]}->{$TransportReactionIDList[$j]}->{"EQUATION"};
=cut
sub GetTransportReactionsForCompoundIDList {
	my($self,$CompoundIDListRef) = @_;

	#Loading the reaction lookup database file
	my $ReactionDatabase = &LoadMultipleLabeledColumnFile($self->{"Reaction database filename"}->[0],";","\\|");

	#Searching through the reaction list for the compound transporters
	my $TransportDataHash;
	for (my $i=0; $i < @{$ReactionDatabase}; $i++) {
		if (defined($ReactionDatabase->[$i]->{"EQUATION"})) {
			#Checking to see if this reaction is a transporter
			if ($ReactionDatabase->[$i]->{"EQUATION"}->[0] =~ m/\[e\]/) {
				#Now checking to see if it is a transporter for any of my query compounds
				for (my $j=0; $j < @{$CompoundIDListRef}; $j++) {
					my $Compound = $CompoundIDListRef->[$j];
					if ($ReactionDatabase->[$i]->{"EQUATION"}->[0] =~ m/$Compound\[e\]/) {
					$TransportDataHash->{$CompoundIDListRef->[$j]}->{$ReactionDatabase->[$i]->{"DATABASE"}->[0]} = $ReactionDatabase->[$i];
					}
				}
			}
		}
	}

	return $TransportDataHash;
}

=head3 name_of_keggmap

Definition:
	$Name = $model->name_of_keggmap($Map);

Description:

Example:

=cut

sub name_of_keggmap {
	my ($self,$Map) = @_;

	if (!defined($self->{"kegg map names"})) {
	($self->{"kegg map names"}->{"num hash"},$self->{"kegg map names"}->{"name hash"}) = &LoadSeparateTranslationFiles($self->{"kegg map name file"}->[0],"\t");
	}

	if ($Map =~ m/(\d+$)/) {
	$Map = $1;
	}

	return $self->{"kegg map names"}->{"num hash"}->{$Map};
}

=head3 get_predicted_essentials
Definition:
	$ReactionList = $model->get_predicted_essentials($Model);
Description:
=cut

sub get_predicted_essentials {
	my ($self,$Model,$Media) = @_;

	#Setting media to "Complete" if the media is undefined
	if (!defined($Media)) {
		$Media = "Complete";
	}

	#Checking if the essential gene file exists
	my $modelObj = $self->get_model($Model);
	if (defined($modelObj) && -e $modelObj->directory()."EssentialGenes-".$Model."-".$Media.".tbl") {
		return $self->database()->load_single_column_file($modelObj->directory()."EssentialGenes-".$Model."-".$Media.".tbl","");
	}

	return undef;
}

=head3 status_of_model
Definition:
	int::model status = FIGMODEL->status_of_model(string::model ID);
	string::model status message = FIGMODEL->status_of_model(string::genome ID,1);
Description:
	Returns the current status of the SEED model associated with the input genome ID.
	model status = 1: model exists
	model status = 0: model is being built
	model status = -1: model does not exist
	model status = -2: model build failed
=cut

sub status_of_model {
	my ($self,$ModelID,$GetMessage) = @_;

	if ($ModelID =~ m/^\d+\.\d+$/) {
		$ModelID = "Seed".$ModelID;
	}
	my $model = $self->get_model($ModelID);
	#Returning the message if requested
	if (defined($GetMessage) && $GetMessage == 1) {
		if (!defined($model)) {
			return "NONE";
		}
		return $model->message();
	}

	#Checking if the model data was returned
	if (!defined($model)) {
		return -1;
	}
	return $model->status();
}

=head3 reactions_of_subsystem
Definition:
	$Scenarios = $model->reactions_of_subsystem($Subsystem,$Model);
=cut

sub reactions_of_subsystem {
	my ($self,$Subsystem) = @_;

	#Loading the functional role mapping if needed
	$self->LoadFunctionalRoleMapping();

	#Checking if the reaction is in the mapping
	if (defined($self->{"FUNCTIONAL ROLE MAPPING"}->{"SUBSYSTEM HASH"}->{$Subsystem})) {
	my %ReactionHash;
	foreach my $Mapping (@{$self->{"FUNCTIONAL ROLE MAPPING"}->{"SUBSYSTEM HASH"}->{$Subsystem}}) {
		if (defined($Mapping->{"REACTION"}) && $Mapping->{"REACTION"}->[0] =~ m/rxn\d\d\d\d\d/) {
		$ReactionHash{$Mapping->{"REACTION"}->[0]} = 1;
		}
	}
	my $Reactions;
	push(@{$Reactions},keys(%ReactionHash));
	return $Reactions;
	} else {
	return undef;
	}

	return undef;
}

=head3 reactions_of_map

Definition:
	$Reactions = $model->reactions_of_subsystem($Map);

Description:

Example:

=cut

sub reactions_of_map {
	my ($self,$Map) = @_;

	#Loading the scenario data file if it needs to be loaded
	$self->LoadReactionDatabaseFile();

	my $ReactionList;
	if (defined($self->{"DATABASE"}->{"MAPS"}->{$Map})) {
	$ReactionList = $self->{"DATABASE"}->{"MAPS"}->{$Map};
	} else {
	$ReactionList = undef;
	}

	return $ReactionList;
}

=head3 scenarios_of_reaction

Definition:
	$Scenarios = $model->scenarios_of_reaction($Reaction);

Description:

Example:

=cut

sub scenarios_of_reaction {
	my ($self,$Reaction) = @_;

	#Loading the scenario data file if it needs to be loaded
	if (!defined($self->{"scenario data"})) {
	$self->LoadScenarios();
	}

	my $ScenarioList;
	if (defined($self->{"scenario data"}->{"reaction hash"}->{$Reaction})) {
	$ScenarioList = $self->{"scenario data"}->{"reaction hash"}->{$Reaction};
	} else {
	$ScenarioList = undef;
	}

	return $ScenarioList;
}

=head3 reactions_of_scenario

Definition:
	$Reactions = $model->reactions_of_scenario($Scenario);

Description:

Example:

=cut

sub reactions_of_scenario {
	my ($self,$Scenario,$Model) = @_;

	#Loading the scenario data file if it needs to be loaded
	if (!defined($self->{"scenario data"})) {
		$self->LoadScenarios();
	}

	my $Reactions;
	if (defined($self->{"scenario data"}->{"scenario hash"}->{$Scenario})) {
		$Reactions = $self->{"scenario data"}->{"scenario hash"}->{$Scenario};
	} else {
		$Reactions = undef;
	}

	if (!defined($Model) || length($Model) == 0 || $Model eq "NONE") {
		return $Reactions;
	}

	my $FinalReactionList;
	foreach my $Reaction (@{$Reactions}) {
		if (defined($self->GetDBModel($Model)->get_row_by_key($Reaction,"LOAD"))) {
			push(@{$FinalReactionList},$Reaction);
		}
	}

	return $FinalReactionList;
}

=head3 colocalized_genes
Definition:
	(1/0) = FIGMODEL->colocalized_genes(string:gene one,string:gene two,string:genome ID);
Description:
	This function assesses whether or not the specified genes are near one another on the specified genome
=cut
sub colocalized_genes {
	my ($self,$geneOne,$geneTwo,$genomeID) = @_;

	my $features = $self->database()->get_genome_feature_table($genomeID);
	my $rowOne = $features->get_row_by_key("fig|".$genomeID.".".$geneOne,"ID");
	my $rowTwo = $features->get_row_by_key("fig|".$genomeID.".".$geneTwo,"ID");	
	my $difference = $rowOne->{"MIN LOCATION"}->[0] - $rowTwo->{"MIN LOCATION"}->[0];
	if ($difference < 0) {
		$difference = -$difference;
	}
	if ($difference < 20000) {
		return 1;
	}
	return 0;
}

=head3 OptimizeAnnotation
Definition:
	$model->OptimizeAnnotation($ModelName);
Description:
Example:
=cut

sub OptimizeAnnotation {
	my ($self,$ModelList) = @_;

	#All results will be stored in this hash like so: ->{Essential role set}->{Non essential roles}->{Reactions}->{Organism}->{Essential genes}/{Nonessential genes}/{Current complexes}/{Recommendation};
	my $CombinedResultsHash;

	#Experimental essential roles
	my $RoleTable = ModelSEED::FIGMODEL::FIGMODELTable->new(["Role","Genes","Reactions","Organisms"],$self->{"database message file directory"}->[0]."ExperimentalEssentialRoles.txt",["Role","Genes"],"\t","|",undef);

	#Cycling through the list of model IDs
	for (my $i=0; $i < @{$ModelList}; $i++) {
		my $ModelName = $ModelList->[$i];
		#Loading the model table
		my $ModelTable = $self->database()->GetDBModel($ModelName);
		if (defined($ModelTable)) {
			#Getting model data
			my $ModelRow = $self->database()->GetDBTable("MODEL LIST")->get_row_by_key($ModelName,"MODEL ID");
			my $ModelDirectory = $self->{"database root directory"}->[0].$ModelRow->{"DIRECTORY"}->[0];
			my $OrganismID = $ModelRow->{"ORGANISM ID"}->[0];

			#Getting essential gene list
			my $ExperimentalEssentialGenes = $self->GetEssentialityData($OrganismID);
			if (defined($ExperimentalEssentialGenes)) {
				#Getting the feature table
				my $FeatureTable = $self->GetGenomeFeatureTable($OrganismID);
				$FeatureTable->save();
				#Putting essential genes in a hash and populating the essential gene role table
				my %EssentialGeneHash;
				my %NonessentialGeneHash;
				for (my $i=0; $i < $ExperimentalEssentialGenes->size(); $i++) {
					my $Row = $ExperimentalEssentialGenes->get_row($i);
					if (defined($Row->{"Gene"}->[0]) && defined($Row->{"Essentiality"}->[0]) && $Row->{"Essentiality"}->[0] eq "essential") {
						my $FeatureRow = $FeatureTable->get_row_by_key("fig|".$OrganismID.".".$Row->{"Gene"}->[0],"ID");
						if (defined($FeatureRow->{"ROLES"})) {
							foreach my $Role (@{$FeatureRow->{"ROLES"}}) {
								my $RoleRow = $RoleTable->get_row_by_key($Role,"Role");
								if (defined($RoleRow)) {
									$RoleTable->add_data($RoleRow,["Organisms"],$OrganismID,1);
									$RoleTable->add_data($RoleRow,["Genes"],"fig|".$OrganismID.".".$Row->{"Gene"}->[0],1);
								} else {
									$RoleTable->add_row({"Role" => [$Role],"Genes" => ["fig|".$OrganismID.".".$Row->{"Gene"}->[0]],"Organisms" => [$OrganismID]});
								}
							}
						}
						$EssentialGeneHash{$Row->{"Gene"}->[0]} = 1;
					} elsif (defined($Row->{"Gene"}->[0]) && defined($Row->{"Essentiality"}->[0]) && $Row->{"Essentiality"}->[0] eq "nonessential") {
						$NonessentialGeneHash{$Row->{"Gene"}->[0]} = 1;
					}
				}

				#Classifying reactions
				#my $ClassTable = $self->ClassifyModelReactions($ModelName,"Complete");

				#Scanning through reactions looking for essential and nonessential genes mapped to the same reaction
				my %ReactionComplexHash;
				for (my $i=0; $i < $ModelTable->size(); $i++) {
					my $ModelRow = $ModelTable->get_row($i);
					if (defined($ModelRow->{"ASSOCIATED PEG"}->[0])) {
						#Checking if an essential peg is mapped to this reaction
						my $ReactionEssentialGeneHash;
						my $ReactionNonEssentialGeneHash;
						my $ReactionUnknownGeneHash;
						my $ComplexArray;
						my $MarkedComplexes;
						my $NewGeneLists;
						my $NewComplexes;
						my $InvolvesEssentials = 0;
						for (my $j=0; $j < @{$ModelRow->{"ASSOCIATED PEG"}}; $j++) {
							my $Class = "";
							my @Pegs = split(/\+/,$ModelRow->{"ASSOCIATED PEG"}->[$j]);
							push(@{$NewGeneLists->[$j]},@Pegs);
							my @MarkedPegs;
							for (my $k=0; $k < @Pegs; $k++) {
								if (defined($EssentialGeneHash{$Pegs[$k]}) && !defined($ReactionEssentialGeneHash->{$Pegs[$k]})) {
									$InvolvesEssentials = 1;
									$ReactionEssentialGeneHash->{$Pegs[$k]}->[$j] = 1;
									my $RoleRow = $RoleTable->get_row_by_key("fig|".$OrganismID.".".$Pegs[$k],"Genes");
									if (defined($RoleRow)) {
										$RoleTable->add_data($RoleRow,"Reactions",$ModelRow->{"LOAD"}->[0].$Class,1);
									}
									$MarkedPegs[$k] = $Pegs[$k]."(E)";
								} elsif (defined($NonessentialGeneHash{$Pegs[$k]})) {
									if (!defined($ReactionNonEssentialGeneHash->{$Pegs[$k]})) {
										$ReactionNonEssentialGeneHash->{$Pegs[$k]} = 0;
									}
									$ReactionNonEssentialGeneHash->{$Pegs[$k]}++;
									$MarkedPegs[$k] = $Pegs[$k]."(N)";
								} else {
									if (!defined($ReactionUnknownGeneHash->{$Pegs[$k]})) {
										$ReactionUnknownGeneHash->{$Pegs[$k]} = 0;
									}
									$ReactionUnknownGeneHash->{$Pegs[$k]}++;
									$MarkedPegs[$k] = $Pegs[$k]."(U)";
								}
							}
							push(@{$ComplexArray},join("+",sort(@Pegs)));
							push(@{$MarkedComplexes},join("+",sort(@MarkedPegs)));
						}
						my @EssentialsList = keys(%{$ReactionEssentialGeneHash});
						my @NonessentialsList = keys(%{$ReactionNonEssentialGeneHash});
						my $Change = 0;
						if ($InvolvesEssentials == 1) {
							for (my $j=0; $j < @{$NewGeneLists}; $j++) {
								for (my $m=0; $m < @EssentialsList; $m++) {
									my $Match = 0;
									for (my $k=0; $k < @{$NewGeneLists->[$j]}; $k++) {
										if ($EssentialsList[$m] eq $NewGeneLists->[$j]->[$k]) {
											$Match = 1;
											last;
										}
									}
									if ($Match != 1) {
										push(@{$NewGeneLists->[$j]},$EssentialsList[$m]);
										$Change = 1;
									}
								}
								for (my $m=0; $m < @NonessentialsList; $m++) {
									if ($ReactionNonEssentialGeneHash->{$NonessentialsList[$m]} == @{$ModelRow->{"ASSOCIATED PEG"}}) {
										for (my $k=0; $k < @{$NewGeneLists->[$j]}; $k++) {
											if ($NonessentialsList[$m] eq $NewGeneLists->[$j]->[$k]) {
												$Change = 1;
												splice(@{$NewGeneLists->[$j]},$k,1);
												$k--;
											}
										}
									}
								}
								push(@{$NewComplexes},join("+",sort(@{$NewGeneLists->[$j]})));
							}
							if ($Change == 1) {
								my $ComplexString = join(",",sort(@{$ComplexArray}));
								push(@{$ReactionComplexHash{$ComplexString}->{"REACTIONS"}},$ModelRow->{"LOAD"}->[0]);
								if (!defined($ReactionComplexHash{$ComplexString}->{"ESSENTIALS"})) {
									$ReactionComplexHash{$ComplexString}->{"ESSENTIALS"} = $ReactionEssentialGeneHash;
									$ReactionComplexHash{$ComplexString}->{"NONESSENTIALS"} = $ReactionNonEssentialGeneHash;
									$ReactionComplexHash{$ComplexString}->{"UNKNOWNS"} = $ReactionUnknownGeneHash;
									$ReactionComplexHash{$ComplexString}->{"COMPLEXES"} = $MarkedComplexes;
									$ReactionComplexHash{$ComplexString}->{"NEWCOMPLEXES"} = $NewComplexes;
								}
							}
						}
					}
				}

				#Populating output table for this model
				my @ComplexSets = keys(%ReactionComplexHash);
				foreach my $SingleComplex (@ComplexSets) {
					#Generating reaction set strings
					my @ReactionList = sort(@{$ReactionComplexHash{$SingleComplex}->{"REACTIONS"}});
					my $ReactionSet = join(",",@ReactionList);
					#for (my $i=0; $i < @ReactionList; $i++) {
					#	$ReactionList[$i] = $ReactionList[$i]."(".$ClassTable->get_row_by_key($ReactionList[$i],"REACTION")->{"CLASS"}->[0].")";
					#}
					my $ReactionClassString = join(",",@ReactionList);
					#Dealing with gene essentiality
					my $EssentialsArray;
					my $NonessentialsArray;
					my $UnknownArray;
					my @EssentialRoles;
					my %NonessentialRoles;
					my @EssentialList = keys(%{$ReactionComplexHash{$SingleComplex}->{"ESSENTIALS"}});
					my @NonessentialList = keys(%{$ReactionComplexHash{$SingleComplex}->{"NONESSENTIALS"}});
					my @UnknownList = keys(%{$ReactionComplexHash{$SingleComplex}->{"UNKNOWNS"}});
					foreach my $Gene (@EssentialList) {
						my $GeneRole = "";
						my $GeneRow = $FeatureTable->get_row_by_key("fig|".$OrganismID.".".$Gene,"ID");
						if (defined($GeneRow) && defined($GeneRow->{"ROLES"})) {
							$GeneRole = join("|",@{$GeneRow->{"ROLES"}});
						}
						push(@{$EssentialsArray},$Gene.":".$GeneRole);
						push(@EssentialRoles,$GeneRole);
					}
					foreach my $Gene (@NonessentialList) {
						my $GeneRole = "";
						my $GeneRow = $FeatureTable->get_row_by_key("fig|".$OrganismID.".".$Gene,"ID");
						if (defined($GeneRow) && defined($GeneRow->{"ROLES"})) {
							$GeneRole = join("|",@{$GeneRow->{"ROLES"}});
						}
						push(@{$NonessentialsArray},$Gene.":".$GeneRole);
						$NonessentialRoles{$GeneRole}=1;
					}
					foreach my $Gene (@UnknownList) {
						my $GeneRole = "";
						my $GeneRow = $FeatureTable->get_row_by_key("fig|".$OrganismID.".".$Gene,"ID");
						if (defined($GeneRow) && defined($GeneRow->{"ROLES"})) {
							$GeneRole = join("|",@{$GeneRow->{"ROLES"}});
						}
						push(@{$UnknownArray},$Gene.":".$GeneRole);
					}
					my $EssentialRoleString = join("+",sort(@EssentialRoles));
					my $NonessentialRoleString = join(",",sort(keys(%NonessentialRoles)));
					#Loading the data into the combined results hash
					$CombinedResultsHash->{$ReactionSet}->{$OrganismID}->{"ESSENTIALS"} = $EssentialsArray;
					$CombinedResultsHash->{$ReactionSet}->{$OrganismID}->{"NONESSENTIALS"} = $NonessentialsArray;
					$CombinedResultsHash->{$ReactionSet}->{$OrganismID}->{"UNKNOWNS"} = $UnknownArray;
					$CombinedResultsHash->{$ReactionSet}->{$OrganismID}->{"COMPLEX"} = $ReactionComplexHash{$SingleComplex}->{"COMPLEXES"};
					$CombinedResultsHash->{$ReactionSet}->{$OrganismID}->{"NEWCOMPLEX"} = $ReactionComplexHash{$SingleComplex}->{"NEWCOMPLEXES"};
					$CombinedResultsHash->{$ReactionSet}->{$OrganismID}->{"RXNCLASSES"}->[0] = $ReactionClassString;
				}
			} else {
				print STDERR "FIGMODEL:OptimizeAnnotation: No experimental essentiality data found for the specified model!\n";
			}
		} else {
			print STDERR "FIGMODEL:OptimizeAnnotation: Could not load model: ".$ModelName."\n";
		}
	}

	#Printing the results of the analysis
	my $Filename = $self->{"database message file directory"}->[0]."AnnotationOptimizationReport.txt";
	if (!open (OPTIMIZATIONOUTPUT, ">$Filename")) {
		return;
	}

	#All results will be stored in this hash like so: ->{Essential role set}->{Non essential roles}->{Reactions}->{Organism}->{Essential genes}/{Nonessential genes}/{Current complexes}/{Recommendation};
	print OPTIMIZATIONOUTPUT "NOTE;Essential roles;Nonessential roles;Reactions\n";
	my @ReactionKeys = keys(%{$CombinedResultsHash});
	foreach my $ReactionKey (@ReactionKeys) {
		print OPTIMIZATIONOUTPUT "NEW ESSENTIALS;".$ReactionKey."\n";
		my @Organisms = keys(%{$CombinedResultsHash->{$ReactionKey}});
		foreach my $OrganismItem (@Organisms) {
			print OPTIMIZATIONOUTPUT "ORGANISM:".$OrganismItem."\n";
			print OPTIMIZATIONOUTPUT "REACTIONS CLASSIFIED:".$CombinedResultsHash->{$ReactionKey}->{$OrganismItem}->{"RXNCLASSES"}->[0]."\n";
			print OPTIMIZATIONOUTPUT "ESSENTIALS;NONESSENTIALS;UNKNOWNS\n";
			my $Count = 0;
			while (defined($CombinedResultsHash->{$ReactionKey}->{$OrganismItem}->{"ESSENTIALS"}->[$Count]) || defined($CombinedResultsHash->{$ReactionKey}->{$OrganismItem}->{"NONESSENTIALS"}->[$Count])) {
				if (defined($CombinedResultsHash->{$ReactionKey}->{$OrganismItem}->{"ESSENTIALS"}->[$Count])) {
					print OPTIMIZATIONOUTPUT $CombinedResultsHash->{$ReactionKey}->{$OrganismItem}->{"ESSENTIALS"}->[$Count];
				}
				print OPTIMIZATIONOUTPUT ";";
				if (defined($CombinedResultsHash->{$ReactionKey}->{$OrganismItem}->{"NONESSENTIALS"}->[$Count])) {
					print OPTIMIZATIONOUTPUT $CombinedResultsHash->{$ReactionKey}->{$OrganismItem}->{"NONESSENTIALS"}->[$Count];
				}
				print OPTIMIZATIONOUTPUT ";";
				if (defined($CombinedResultsHash->{$ReactionKey}->{$OrganismItem}->{"UNKNOWNS"}->[$Count])) {
					print OPTIMIZATIONOUTPUT $CombinedResultsHash->{$ReactionKey}->{$OrganismItem}->{"UNKNOWNS"}->[$Count];
				}
				print OPTIMIZATIONOUTPUT "\n";
				$Count++;
			}
			print OPTIMIZATIONOUTPUT "Current complex;Recommended complex\n";
			$Count = 0;
			while (defined($CombinedResultsHash->{$ReactionKey}->{$OrganismItem}->{"COMPLEX"}->[$Count]) || defined($CombinedResultsHash->{$ReactionKey}->{$OrganismItem}->{"NEWCOMPLEX"}->[$Count])) {
				if (defined($CombinedResultsHash->{$ReactionKey}->{$OrganismItem}->{"COMPLEX"}->[$Count])) {
					print OPTIMIZATIONOUTPUT $CombinedResultsHash->{$ReactionKey}->{$OrganismItem}->{"COMPLEX"}->[$Count];
				}
				print OPTIMIZATIONOUTPUT ";";
				if (defined($CombinedResultsHash->{$ReactionKey}->{$OrganismItem}->{"NEWCOMPLEX"}->[$Count])) {
					print OPTIMIZATIONOUTPUT $CombinedResultsHash->{$ReactionKey}->{$OrganismItem}->{"NEWCOMPLEX"}->[$Count];
				}
				print OPTIMIZATIONOUTPUT "\n";
				$Count++;
			}
		}
	}

	$RoleTable->save();
	close(OPTIMIZATIONOUTPUT);
}

=head3 create_model
Definition:
	FIGMODELmodel FIGMODEL->create_model({
		genome => string:genome ID,
		id => string:model ID,
		owner => string:owner,
		biochemSource => string:directory where biochemistry for new model should be pulled from,
		biomassReaction => string:biomass ID,
		reconstruction => 0/1,
		gapfilling => 0/1,
		usequeue => 0/1,
		queue => string:queue name
	});
Description:
=cut
sub create_model {
	my ($self,$args) = @_;
	return ModelSEED::FIGMODEL::FIGMODELmodel->new({
			figmodel => $self,
			id => $args->{id},
			init => $args
	});
}

=head3 createNewModel
Legacy interface for ModelViewer construction
#LEGACY-SEEDWEB
=cut
sub createNewModel {
    my ($self, $args) = @_;
    $args->{genome} = $args->{'-genome'};
    delete $args->{'-genome'};
    return $self->create_model($args);
}

=head3 compareManyModels
Definition:
	FIGMODEL->compareManyModels({ids => [string]:model IDs})
=cut
sub compareManyModels {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["ids"],{});
	my $modelHash;
	for (my $i=0; $i < @{$args->{ids}}; $i++) {
		$modelHash->{$args->{ids}->[$i]} = $self->get_model($args->{ids}->[$i]);
		if (!defined($modelHash->{$args->{ids}->[$i]})) {
			$self->figmodel()->new_error_message({package => "FIGMODEL",message=> "Could not load ".$args->{ids}->[$i]." model.",function => "add_constraint",args=>$args});	
		}
	}
	
	
}

=head3 CompareModelGenes
Definition:
	FIGMODELTable:Gene comparison genes = FIGMODEL->CompareModelGenes(string:model one,string:model two)
Description:
=cut

sub CompareModelGenes {
	my ($self,$ModelOne,$ModelTwo) = @_;
	#Loading models
	my $One = $self->get_model($ModelOne);
	my $Two = $self->get_model($ModelTwo);
	#Checking that both models exist
	if (!defined($One)) {
		print STDERR "FIGMODEL->CompareModelGenes(".$ModelOne.",".$ModelTwo.") ".$ModelOne." not found!\n";
		return undef;
	}
	if (!defined($Two)) {
		print STDERR "FIGMODEL->CompareModelGenes(".$ModelOne.",".$ModelTwo.") ".$ModelTwo." not found!\n";
		return undef;
	}
	#Getting subsystem link table
	my $linktbl = $self->database()->GetLinkTable("SUBSYSTEM","ROLE");
	#Creating the output table
	my $tbl = ModelSEED::FIGMODEL::FIGMODELTable->new(["EXTRA PEG","ROLE","SUBSYSTEM","CLASS 1","CLASS 2","REACTIONS","OTHER MODEL PEGS","REFERENCE MODEL"],$self->{"database message file directory"}->[0].$ModelOne."-".$ModelTwo."-GeneComparison.tbl",["PEG"],"\t","|",undef);
	#Getting gene tables
	my $GeneTblOne = $One->feature_table();
	my $GeneTblTwo = $Two->feature_table();
	my $RxnTblOne = $One->reaction_table();
	my $RxnTblTwo = $Two->reaction_table();
	for (my $m=0; $m < 2; $m++) {
		if ($m == 1) {
			my $temp = $GeneTblOne;
			$GeneTblOne = $GeneTblTwo;
			$GeneTblTwo = $temp;
			$temp = $RxnTblOne;
			$RxnTblOne = $RxnTblTwo;
			$RxnTblTwo = $temp;
			$temp = $ModelOne;
			$ModelOne = $ModelTwo;
			$ModelTwo = $temp;
		}
		for (my $i=0; $i < $GeneTblOne->size(); $i++) {
			my $row = $GeneTblOne->get_row($i);
			if (!defined($GeneTblTwo->get_row_by_key($row->{ID}->[0],"ID"))) {
				my $newrow = $tbl->add_row({"EXTRA PEG"=>[$row->{ID}->[0]],"ROLE"=>$row->{ROLES},"REACTIONS"=>$row->{$ModelOne},"REFERENCE MODEL"=>[$ModelOne]});
				if (defined($newrow->{"ROLE"})) {
					for (my $j=0; $j < @{$newrow->{"ROLE"}}; $j++) {
						my @subsysrows = $linktbl->get_rows_by_key($newrow->{"ROLE"}->[$j],"ROLE");
						my $subsys;
						my $classOne;
						my $classTwo;
						for (my $k=0; $k < @subsysrows; $k++) {
							my $classes = $self->class_of_subsystem($subsysrows[$k]->{SUBSYSTEM}->[0]);
							if (defined($classes)) {
								if (length($subsys) > 0) {
									$subsys .= ",";
									$classOne .= ",";
									$classTwo .= ",";
								}
								$subsys .= $subsysrows[$k]->{SUBSYSTEM}->[0];
								$classOne .= $classes->[0];
								$classTwo .= $classes->[1];
							}
						}
						push(@{$newrow->{"SUBSYSTEM"}},$subsys);
						push(@{$newrow->{"CLASS 1"}},$classOne);
						push(@{$newrow->{"CLASS 2"}},$classTwo);
					}
				}
				if (defined($newrow->{"REACTIONS"})) {
					for (my $j=0; $j < @{$newrow->{"REACTIONS"}}; $j++) {
						my $rxnrow = $RxnTblTwo->get_row_by_key($newrow->{"REACTIONS"}->[$j],"LOAD");
						if (!defined($rxnrow)) {
							push(@{$newrow->{"OTHER MODEL PEGS"}},"NA");
						} else {
							push(@{$newrow->{"OTHER MODEL PEGS"}},join(",",@{$rxnrow->{"ASSOCIATED PEG"}}));
						}
					}
				}
			}
		}
	}
	$tbl->save();
	return $tbl;
}

=head3 CompareReactionDirection
Definition:
	$model->CompareReactionDirection();
Description:
Example:
=cut

sub CompareReactionDirection {
	my ($self,$OldReaction,$NewReaction) = @_;

	my $OldReactionData = $self->LoadObject($OldReaction);
	my $NewReactionData = $self->LoadObject($NewReaction);

	if ($OldReactionData ne "0" && $NewReactionData ne "0" && defined($OldReactionData->{"EQUATION"}) && defined($NewReactionData->{"EQUATION"})) {
	if ($OldReactionData->{"EQUATION"}->[0] eq $NewReactionData->{"EQUATION"}->[0]) {
		return "SAME";
	} else {
		return "DIFFERENT";
	}
	}

	return "SAME";
}

=head3 LoadObject
Definition:
my $ObjectDataHashRef = $model->LoadObject($ObjectID);
Description:
	This function loads the specified object file and stores the object data in a hash, which is then returned as a reference.
	The keys of this hash are the first words on each line of the object file. Each hash value is an array of the subsequent words on each line.
	"Words" in this file are separated by tabs.
	The keys in the hash are also stored in an array behind the hash key "orderedkeys" in the order that they were read in from the file.
	This array is useful when you want to print the object data in a specific order everytime.
	0 is returned if the files doesn't exist
Example:
	my $ObjectData = $model->LoadObject("cpd00001");
	print "Object name: ".$ObjectData->{"NAME"}->[0];
	for (my $i=0; $i < @{$ObjectData->{"orderedkeys"}}; $i++) {
	print $ObjectData->{"orderedkeys"}->[$i].": ".join(", ",@{$ObjectData->{$ObjectData->{"orderedkeys"}->[$i]}});
	}
=cut

sub LoadObject {
	my ($self,$ObjectID,$HeadingTranslation) = @_;

	my $Filename = "";

	#Identifying the object type from the ID
	if ($ObjectID =~ m/cpd\d\d\d\d\d/) {
		$Filename = $self->{"compound directory"}->[0].$ObjectID;
	} elsif ($ObjectID =~ m/rxn\d\d\d\d\d/ || $ObjectID =~ m/bio\d\d\d\d\d/) {
		$Filename = $self->{"reaction directory"}->[0].$ObjectID;
	} elsif ($ObjectID =~ m/C\d\d\d\d\d/) {
		$Filename = $self->{"KEGG directory"}->[0]."compounds/".$ObjectID;
	} elsif ($ObjectID =~ m/R\d\d\d\d\d/) {
		$Filename = $self->{"KEGG directory"}->[0]."reactions/".$ObjectID;
	} else {
		print "Object ID type no recognized.\n";
		return 0;
	}

	#Checking if the object has been cached
	if (defined($self->{"CACHE"}->{$ObjectID})) {
		return $self->{"CACHE"}->{$ObjectID};
	}

	#Checking that the file exists
	if (-e $Filename) {
		#For now we load the reaction from a flat file, some day we may load from an SQL DB
		my $ReactionData = &LoadHorizontalDataFile($Filename,"\t",$HeadingTranslation);
		$self->{"CACHE"}->{$ObjectID} = $ReactionData;
		return $ReactionData;
	}

	print "Object file not found:".$Filename."\n";
	return 0;
}

=head3 SaveObject

Definition:
my $Status = $model->SaveObject($ObjectDataHashRef);

Description:
	This function prints the input object back to the database file.
	Each line of the file starts with a key of the hash and continues with each value in the hash array separated by a tab.
	Only keys stored in the "orderkeys" array will be printed, and keys will be printed in the order they are found in the ordered keys array.
	0 is returns upon success, 1 is returned otherwise.
Example:
	my $ObjectData = $model->LoadObject("cpd00001");
	#Adding the formula to the object if its not already present
	$model->AddDataToObject($ObjectData,"FORMULA",("H2O"));
	#Printing the object back to file with the formula
	my $Status = $model->SaveObject($ObjectData);
=cut

sub SaveObject {
	my ($self,$ObjectData) = @_;

	#Checking for the object ID
	if (!defined($ObjectData->{"DATABASE"}) || length($ObjectData->{"DATABASE"}->[0]) == 0) {
	print "No object ID found in input object.\n";
	return 1;
	}
	my $ObjectID = $ObjectData->{"DATABASE"}->[0];

	#Identifying the object type from the ID
	my $Filename = "";
	if ($ObjectID =~ m/cpd\d\d\d\d\d/) {
	$Filename = $self->{"compound directory"}->[0].$ObjectID;
	} elsif ($ObjectID =~ m/rxn\d\d\d\d\d/) {
	$Filename = $self->{"reaction directory"}->[0].$ObjectID;
	} elsif ($ObjectID =~ m/C\d\d\d\d\d/) {
	$Filename = $self->{"KEGG directory"}->[0]."compounds/".$ObjectID;
	} elsif ($ObjectID =~ m/R\d\d\d\d\d/) {
	$Filename = $self->{"KEGG directory"}->[0]."reactions/".$ObjectID;
	} else {
	print "Object ID type not recognized.\n";
	return 1;
	}

	#Loading a fresh hash with the data to be saved and cached
	my $FreshData;
	push(@{$FreshData->{"orderedkeys"}},@{$ObjectData->{"orderedkeys"}});
	foreach my $Item (@{$ObjectData->{"orderedkeys"}}) {
	if (defined($ObjectData->{$Item}) && @{$ObjectData->{$Item}} > 0) {
		foreach my $SubItem (@{$ObjectData->{$Item}}) {
		if (length($SubItem) > 0) {
			push(@{$FreshData->{$Item}},$SubItem);
		}
		}
	}
	}

	#Printing the object to file
	$self->{"CACHE"}->{$ObjectID} = $FreshData;
	&SaveHashToHorizontalDataFile($Filename,"\t",$FreshData);

	return 0;
}

=head3 translate_gene_to_protein
Definition:
	$model->translate_gene_to_protein($GeneList);
Description:
Example:
=cut

sub translate_gene_to_protein {
	my($self,$Genes,$Genome) = @_;
	my $FeatureTable = $self->GetGenomeFeatureTable($Genome);
	if (!defined($FeatureTable)) {
		return ("","","");
	}
	my ($ProteinAssociation,$GeneLocus,$GeneGI);
	for (my $j=0; $j < @{$Genes}; $j++) {
		if ($j > 0) {
			$ProteinAssociation .= " or ";
			$GeneLocus .= " or ";
			$GeneGI .= " or ";	
		}
		my $proteinTemp = $Genes->[$j];
		my $locusTemp = $Genes->[$j];
		my $giTemp = $Genes->[$j];
		$_ = $Genes->[$j];
		my @OriginalArray = /(peg\.\d+)/g;
		for (my $i=0; $i < @OriginalArray; $i++) {
			my $Row = $FeatureTable->get_row_by_key("fig|".$Genome.".".$OriginalArray[$i],"ID");
			my $ProteinName = "NONE";
			my $locus = "NONE";
			my $giNum = "NONE";
			if (defined($Row) && defined($Row->{"ALIASES"})) {
				foreach my $Alias (@{$Row->{"ALIASES"}}) {
					if ($Alias =~ m/^[^\d]+$/) {
						$ProteinName = $Alias;
					} elsif ($Alias =~ m/gi\|(\d+)/) {
						$giNum = $1;
					} elsif ($Alias =~ m/LocusTag:(\D+\d+)/) {
						$locus = $1;
					} elsif ($Alias =~ m/^\D{1,2}\d{3,5}\D{0,1}$/) {
						$locus = $Alias;
					}
				}
			}
			my $Gene = $OriginalArray[$i];
			if ($ProteinName ne "NONE") {
				$proteinTemp =~ s/$Gene(\D)/$ProteinName$1/g;
				$proteinTemp =~ s/$Gene$/$ProteinName/g;
			}
			if ($locus ne "NONE") {
				$locusTemp =~ s/$Gene(\D)/$locus$1/g;
				$locusTemp =~ s/$Gene$/$locus/g;
			}
			if ($giNum ne "NONE") {
				$giTemp =~ s/$Gene(\D)/$giNum$1/g;
				$giTemp =~ s/$Gene$/$giNum/g;
			}
		}
		$proteinTemp =~ s/\s//g;
		$locusTemp =~ s/\s//g;
		$giTemp =~ s/\s//g;
		$proteinTemp =~ s/\+/ and /g;
		$locusTemp =~ s/\+/ and /g;
		$giTemp =~ s/\+/ and /g;
		$ProteinAssociation .= $proteinTemp;
		$GeneLocus .= $locusTemp;
		$GeneGI .= $giTemp;
	}
	return ($ProteinAssociation,$GeneLocus,$GeneGI);
}

=head3 SyncDatabaseMolfiles

Definition:
	$model->SyncDatabaseMolfiles();

Description:
	This function renames any updated KEGG and Palsson molfiles to Argonne molfiles and creates a molfile images for any updated molfiles and any molfiles without associated images
	This function should be run whenever new KEGG or Palsson molfiles are added to the database and occasionally after the mapping has been run.

Example:
	$model->SyncDatabaseMolfiles();

=cut

sub SyncDatabaseMolfiles {
	my($self) = @_;

	#Copying over the corrected molfiles
	my @FileList = glob($self->{"corrected Argonne molfile directory"}->[0]."*.mol");
	my %PreservedIDs;
	foreach my $Filename (@FileList) {
		if ($Filename =~ m/(cpd\d\d\d\d\d)\.mol/) {
			system("cp ".$self->{"corrected Argonne molfile directory"}->[0].$1.".mol ".$self->{"Argonne molfile directory"}->[0].$1.".mol");
			system("cp ".$self->{"corrected Argonne molfile directory"}->[0].$1.".mol ".$self->{"Argonne molfile directory"}->[0]."pH7/".$1.".mol");
			$PreservedIDs{$1} = 1;
		}
	}

	#First, reading in the latest mapping of IDs from the translation directory
	my ($CompoundMappings,$HashReferenceForward) = &LoadSeparateTranslationFiles($self->{"Translation directory"}->[0]."CpdToKEGG.txt","\t");

	#Copying over the KEGG molfiles
	my @CompoundIDs = keys(%{$CompoundMappings});
	for (my $i=0; $i < @CompoundIDs; $i++) {
		if (!defined($PreservedIDs{$CompoundIDs[$i]}) && defined($CompoundMappings->{$CompoundIDs[$i]}) && $CompoundMappings->{$CompoundIDs[$i]} =~ m/C\d\d\d\d\d/) {
			$PreservedIDs{$CompoundIDs[$i]} = 1;
			if (-e $self->{"corrected KEGG molfile directory"}->[0].$CompoundMappings->{$CompoundIDs[$i]}.".mol") {
				system("cp ".$self->{"corrected KEGG molfile directory"}->[0].$CompoundMappings->{$CompoundIDs[$i]}.".mol ".$self->{"Argonne molfile directory"}->[0].$CompoundIDs[$i].".mol");
				system("cp ".$self->{"corrected KEGG molfile directory"}->[0].$CompoundMappings->{$CompoundIDs[$i]}.".mol ".$self->{"Argonne molfile directory"}->[0]."pH7/".$CompoundIDs[$i].".mol");
			} elsif (-e $self->{"KEGG directory"}->[0]."mol/pH7/".$CompoundMappings->{$CompoundIDs[$i]}.".mol") {
				system("cp ".$self->{"KEGG directory"}->[0]."mol/pH7/".$CompoundMappings->{$CompoundIDs[$i]}.".mol ".$self->{"Argonne molfile directory"}->[0].$CompoundIDs[$i].".mol");
				system("cp ".$self->{"KEGG directory"}->[0]."mol/pH7/".$CompoundMappings->{$CompoundIDs[$i]}.".mol ".$self->{"Argonne molfile directory"}->[0]."pH7/".$CompoundIDs[$i].".mol");
			} elsif (-e $self->{"KEGG directory"}->[0]."mol/".$CompoundMappings->{$CompoundIDs[$i]}.".mol") {
				system("cp ".$self->{"KEGG directory"}->[0]."mol/".$CompoundMappings->{$CompoundIDs[$i]}.".mol ".$self->{"Argonne molfile directory"}->[0].$CompoundIDs[$i].".mol");
			}
		}
	}

	#Copying over the Palsson molfiles
	my @TranslationFilename = glob($self->{"Translation directory"}->[0]."CpdTo*.txt");
	my %NonOverwrittenCompounds;
	for (my $j=0; $j < @TranslationFilename; $j++) {
		if ($TranslationFilename[$j] ne "CpdToAll.txt" && $TranslationFilename[$j] ne "CpdToKEGG.txt") {
			($CompoundMappings,my $HashReferenceForward) = &LoadSeparateTranslationFiles($TranslationFilename[$j],"\t");
			@CompoundIDs = keys(%{$CompoundMappings});
			for (my $i=0; $i < @CompoundIDs; $i++) {
				if (defined($CompoundMappings->{$CompoundIDs[$i]}) && -e $self->{"Model molfile directory"}->[0].$CompoundMappings->{$CompoundIDs[$i]}.".mol") {
					if (defined($PreservedIDs{$CompoundIDs[$i]})) {
						$NonOverwrittenCompounds{$CompoundIDs[$i]}->{$CompoundMappings->{$CompoundIDs[$i]}} = 1;
					} elsif ($CompoundMappings->{$CompoundIDs[$i]} !~ m/C\d\d\d\d\d/ && $CompoundMappings->{$CompoundIDs[$i]} !~ m/cpd\d\d\d\d\d/ && $CompoundIDs[$i] =~ m/cpd\d\d\d\d\d/) {
						if (-e $self->{"Model molfile directory"}->[0]."pH7/".$CompoundMappings->{$CompoundIDs[$i]}.".mol") {
							system("cp ".$self->{"Model molfile directory"}->[0]."pH7/".$CompoundMappings->{$CompoundIDs[$i]}.".mol ".$self->{"Argonne molfile directory"}->[0].$CompoundIDs[$i].".mol");
							system("cp ".$self->{"Model molfile directory"}->[0]."pH7/".$CompoundMappings->{$CompoundIDs[$i]}.".mol ".$self->{"Argonne molfile directory"}->[0]."pH7/".$CompoundIDs[$i].".mol");
						} elsif (-e $self->{"Model molfile directory"}->[0].$CompoundMappings->{$CompoundIDs[$i]}.".mol") {
							system("cp ".$self->{"Model molfile directory"}->[0].$CompoundMappings->{$CompoundIDs[$i]}.".mol ".$self->{"Argonne molfile directory"}->[0].$CompoundIDs[$i].".mol");
						}
					}
				}
			}
		}
	}

	my $NonOverwrites;
	my @NonOverwriteKeys = keys(%NonOverwrittenCompounds);
	for (my $i=0; $i < @NonOverwriteKeys; $i++) {
		push (@{$NonOverwrites},$NonOverwriteKeys[$i]." not overwritten by the following model molfiles: ".join(".mol ",keys(%{$NonOverwrittenCompounds{$NonOverwriteKeys[$i]}})).".mol");
	}
	PrintArrayToFile($self->{"database message file directory"}->[0]."NonOverwrittenMolfiles.log",$NonOverwrites);
}

=head3 SyncWithTheKEGG

Definition:
	$model->SyncWithTheKEGG();

Description:
	This function is used to process the KEGG directory for syncing with the current Argonne database.
	This should be run whenever a new version of the KEGG has been downloaded.

Example:
	$model->SyncWithTheKEGG();

=cut

sub SyncWithTheKEGG {
	my($self) = @_;

	#Pathway name/ID correspondence will be stored in this hash
	my %PathwayNameHash;

	#Backing up the current KEGG files
	if (-d $self->{"KEGG directory"}->[0]."oldmol") {
	#system("rm -rf ".$self->{"KEGG directory"}->[0]."oldmol")
	}
	if (-d $self->{"KEGG directory"}->[0]."ligand") {
	#system("mv ".$self->{"KEGG directory"}->[0]."mol/ ".$self->{"KEGG directory"}->[0]."oldmol/");
	#system("mv ".$self->{"KEGG directory"}->[0]."reaction ".$self->{"KEGG directory"}->[0]."oldreaction");
	#system("mv ".$self->{"KEGG directory"}->[0]."reaction_mapformula.lst ".$self->{"KEGG directory"}->[0]."oldreaction_mapformula.lst");
	#system("mv ".$self->{"KEGG directory"}->[0]."compound ".$self->{"KEGG directory"}->[0]."oldcompound");
	#system("mv ".$self->{"KEGG directory"}->[0]."enzyme ".$self->{"KEGG directory"}->[0]."oldenzyme");
	#Copying over current KEGG data to the KEGG directory for processing
	#system("cp /vol/biodb/kegg/ligand/reaction/reaction ".$self->{"KEGG directory"}->[0]."reaction");
	#system("cp /vol/biodb/kegg/ligand/reaction/reaction_mapformula.lst ".$self->{"KEGG directory"}->[0]."reaction_mapformula.lst");
	#system("cp /vol/biodb/kegg/ligand/compound/compound ".$self->{"KEGG directory"}->[0]."compound");
	#system("cp /vol/biodb/kegg/ligand/enzyme/enzyme ".$self->{"KEGG directory"}->[0]."enzyme");
	}

	#Deleting the existing old compounds and reactions directories
	if (-d $self->{"KEGG directory"}->[0]."oldcompounds") {
		system("rm -rf ".$self->{"KEGG directory"}->[0]."oldcompounds")
	}
	if (-d $self->{"KEGG directory"}->[0]."oldreactions") {
		system("rm -rf ".$self->{"KEGG directory"}->[0]."oldreactions")
	}

	#Renaming the current compounds and reactions directories
	if (-d $self->{"KEGG directory"}->[0]."compounds") {
	system("mv ".$self->{"KEGG directory"}->[0]."compounds ".$self->{"KEGG directory"}->[0]."oldcompounds");
	}
	if (-d $self->{"KEGG directory"}->[0]."reactions") {
	system("mv ".$self->{"KEGG directory"}->[0]."reactions ".$self->{"KEGG directory"}->[0]."oldreactions");
	}

	#Making new current compounds and reactions directories
	system("mkdir ".$self->{"KEGG directory"}->[0]."compounds");
	system("mkdir ".$self->{"KEGG directory"}->[0]."reactions");

	#Parsing the compound and reaction files into the new current compounds and reactions directories
	my $FileOpen = 0;
	my $Section = "";
	my $FirstName = 1;
	if (open (KEGGINPUT, "<".$self->{"KEGG directory"}->[0]."compound")) {
	while (my $Line = <KEGGINPUT>) {
		chomp($Line);
		my @Data = split(/\s+/,$Line);
		if ($Data[0] =~ m/ENTRY/) {
		if ($FileOpen != 0) {
			close(KEGGOUTPUT);
		} else {
			$FileOpen = 1;
		}
		my $Filename = $self->{"KEGG directory"}->[0]."compounds/".$Data[1];
		open(KEGGOUTPUT, ">$Filename");
		print KEGGOUTPUT "ENTRY\t".$Data[1];
		} elsif ($Line  =~ m/^\s/) {
		shift(@Data);
		if ($Section eq "NAME") {
			for(my $i=0; $i < @Data; $i++) {
			if ($FirstName == 1) {
				print KEGGOUTPUT "\t";
				$FirstName = 0;
			} else {
				print KEGGOUTPUT " ";
			}
			if ($Data[$i] =~ m/;$/) {
				$FirstName = 1;
				$Data[$i] = substr($Data[$i],0,length($Data[$i])-1);
			}
			print KEGGOUTPUT $Data[$i];
			}
		} elsif ($Section eq "ENZYME") {
			for(my $i=0; $i < @Data; $i++) {
			if (length($Data[$i]) <= 3) {
				print KEGGOUTPUT $Data[$i];
			} else {
				print KEGGOUTPUT "\t".$Data[$i];
			}
			}
		} elsif ($Section eq "PATHWAY") {
			#--- I only the pathway name---#
			print KEGGOUTPUT "\t".$Data[1];
			my $MapID = $Data[1];
			shift(@Data);
			shift(@Data);
			$PathwayNameHash{$MapID} = join(" ",@Data);
		} elsif ($Section eq "DBLINKS") {
			print KEGGOUTPUT "\t".$Data[0]." ".$Data[1];
		} elsif ($Section eq "REMARK" || $Section eq "ATOM" || $Section eq "BOND" || $Section eq "///") {
			#Do nothing... these parts of the file are ignored
		} else {
			print KEGGOUTPUT "\t".join("\t",@Data);
		}
		} else {
		$Section = shift(@Data);
		$FirstName = 1;
		if ($Section eq "NAME") {
			print KEGGOUTPUT "\n".$Section;
			for(my $i=0; $i < @Data; $i++) {
			if ($FirstName == 1) {
				print KEGGOUTPUT "\t";
				$FirstName = 0;
			} else {
				print KEGGOUTPUT " ";
			}
			if ($Data[$i] =~ m/;$/) {
				$FirstName = 1;
				$Data[$i] = substr($Data[$i],0,length($Data[$i])-1);
			}
			print KEGGOUTPUT $Data[$i];
			}
		} elsif ($Section eq "ENZYME") {
			print KEGGOUTPUT "\n".$Section;
			for(my $i=0; $i < @Data; $i++) {
			if (length($Data[$i]) <= 3) {
				print KEGGOUTPUT $Data[$i];
			} else {
				print KEGGOUTPUT "\t".$Data[$i];
			}
			}
		} elsif ($Section eq "PATHWAY") {
			print KEGGOUTPUT "\n".$Section."\t".$Data[1];
			my $MapID = $Data[1];
			shift(@Data);
			shift(@Data);
			$PathwayNameHash{$MapID} = join(" ",@Data);
		} elsif ($Section eq "DBLINKS") {
			print KEGGOUTPUT "\n".$Section."\t".$Data[0]." ".$Data[1];
		} elsif ($Section eq "REMARK" || $Section eq "ATOM" || $Section eq "BOND" || $Section eq "///") {
			#Do nothing... these parts of the file are ignored
		} else {
			print KEGGOUTPUT "\n".$Section."\t".join("\t",@Data);
		}
		}
	}
	close (KEGGINPUT);
	}
	$FileOpen = 0;
	$Section = "";
	$FirstName = 1;
	my %ReactionDirections;
	if (open (KEGGINPUT, "<".$self->{"KEGG directory"}->[0]."reaction_mapformula.lst")) {
	while (my $Line = <KEGGINPUT>) {
		chomp($Line);
		my @Data = split(/\s+/,$Line);
		my $ReactionID = substr($Data[0],0,length($Data[0])-1);
		for(my $i=0; $i < @Data; $i++) {
		if ($Data[$i]  =~ m/^=/ || $Data[$i]  =~ m/^</) {
			if (defined($ReactionDirections{$ReactionID})) {
			if ($ReactionDirections{$ReactionID} ne $Data[$i]) {
				$ReactionDirections{$ReactionID} = "<=>";
			}
			} else {
			$ReactionDirections{$ReactionID} = $Data[$i];
			}
		}
		}
	}
	close(KEGGINPUT);
	}
	my $Direction = "<=>";
	if (open (KEGGINPUT, "<".$self->{"KEGG directory"}->[0]."reaction")) {
	while (my $Line = <KEGGINPUT>) {
		chomp($Line);
		my @Data = split(/\s+/,$Line);
		if ($Data[0] =~ m/ENTRY/) {
		if ($FileOpen != 0) {
			close(KEGGOUTPUT);
		} else {
			$FileOpen = 1;
		}
		my $Filename = $self->{"KEGG directory"}->[0]."reactions/".$Data[1];
		open(KEGGOUTPUT, ">$Filename");
		print KEGGOUTPUT "ENTRY\t".$Data[1];
		$Direction = "<=>";
		if (defined($ReactionDirections{$Data[1]})) {
			$Direction = $ReactionDirections{$Data[1]};
		}
		} elsif ($Line  =~ m/^\s/) {
		$FirstName = 1;
		if ($Section eq "NAME") {
			for(my $i=0; $i < @Data; $i++) {
			if ($FirstName == 1) {
				print KEGGOUTPUT "\t";
				$FirstName = 0;
			} else {
				print KEGGOUTPUT " ";
			}
			if ($Data[$i] =~ m/;$/) {
				$FirstName = 1;
				$Data[$i] = substr($Data[$i],0,length($Data[$i])-1);
			}
			print KEGGOUTPUT $Data[$i];
			}
		} elsif ($Section eq "ENZYME") {
			for(my $i=0; $i < @Data; $i++) {
			if (length($Data[$i]) <= 3) {
				print KEGGOUTPUT $Data[$i];
			} else {
				print KEGGOUTPUT "\t".$Data[$i];
			}
			}
		} elsif ($Section eq "DEFINITION" || $Section eq "EQUATION" || $Section eq "COMMENT") {
			print KEGGOUTPUT " ".join(" ",@Data);
		} elsif ($Section eq "PATHWAY") {
			#--- I only print the map ID... we dont need to print the name every time ---#
			print KEGGOUTPUT "\t".$Data[2];
			my $MapID = $Data[2];
			shift(@Data);
			shift(@Data);
			shift(@Data);
			$PathwayNameHash{$MapID} = join(" ",@Data);
		} elsif ($Section eq "ORTHOLOGY") {
			#--- I only print the map ID... we dont need to print the name every time ---#
			print KEGGOUTPUT "\t".$Data[2];
		} elsif ($Section eq "///" || $Section eq "RPAIR") {
			#Do nothing... these parts of the file are ignored
		} else {
			print KEGGOUTPUT "\t".join("\t",@Data);
		}
		} else {
		$Section = shift(@Data);
		$FirstName = 1;
		if ($Section eq "NAME") {
			print KEGGOUTPUT "\n".$Section;
			for(my $i=0; $i < @Data; $i++) {
			if ($FirstName == 1) {
				print KEGGOUTPUT "\t";
				$FirstName = 0;
			} else {
				print KEGGOUTPUT " ";
			}
			if ($Data[$i] =~ m/;$/) {
				$FirstName = 1;
				$Data[$i] = substr($Data[$i],0,length($Data[$i])-1);
			}
			print KEGGOUTPUT $Data[$i];
			}
		} elsif ($Section eq "ENZYME") {
			print KEGGOUTPUT "\n".$Section;
			for(my $i=0; $i < @Data; $i++) {
			if (length($Data[$i]) <= 3) {
				print KEGGOUTPUT $Data[$i];
			} else {
				print KEGGOUTPUT "\t".$Data[$i];
			}
			}
		} elsif ($Section eq "DEFINITION" || $Section eq "COMMENT") {
			print KEGGOUTPUT "\n".$Section."\t".join(" ",@Data);
		} elsif ($Section eq "EQUATION") {
			for(my $i=0; $i < @Data; $i++) {
			if ($Data[$i] eq "<=>") {
				$Data[$i] = $Direction;
			}
			}
			print KEGGOUTPUT "\n".$Section."\t".join(" ",@Data);
		} elsif ($Section eq "PATHWAY") {
			#--- I only print the map ID... we dont need to print the name every time ---#
			print KEGGOUTPUT "\n".$Section."\t".$Data[1];
			my $MapID = $Data[1];
			shift(@Data);
			shift(@Data);
			$PathwayNameHash{$MapID} = join(" ",@Data);
		} elsif ($Section eq "ORTHOLOGY") {
			print KEGGOUTPUT "\n".$Section."\t".$Data[1];
		} elsif ($Section eq "///" || $Section eq "RPAIR") {
			#Do nothing... these parts of the file are ignored
		} else {
			print KEGGOUTPUT "\n".$Section."\t".join("\t",@Data);
		}
		}
	}
	close (KEGGINPUT);
	}

	#Printing the key assocaiting map IDs to names
	if (open (KEGGOUTPUT, ">".$self->{"KEGG directory"}->[0]."MapIDKey.txt")) {
	my @MapIDList = keys(%PathwayNameHash);
	for (my $i=0; $i < @MapIDList; $i++) {
		print KEGGOUTPUT $MapIDList[$i]."\t".$PathwayNameHash{$MapIDList[$i]}."\n";
	}
	close(KEGGOUTPUT);
	}
}

=head3 UpdateFunctionalRoleMappings
Definition:
	$model->UpdateFunctionalRoleMappings();
Description:
Example:
	$model->UpdateFunctionalRoleMappings();
=cut

sub UpdateFunctionalRoleMappings {
	my($self) = @_;

	#Loading the file listing the functional roles that have been renamed
	my $Data = LoadSingleColumnFile("/vol/seed-anno-mirror/FIG/Data/Logs/functionalroles.rewrite","");
	
	#Building the role name translation hash
	my $RoleTranslation;
	my $TranslatedTo;
	foreach my $Line (@{$Data}) {
		if ($Line =~ m/^Role\s(.+)\swas\sreplaced\sby\s(.+)\s*$/) {
			if (defined($TranslatedTo->{$1})) {
				#$RoleTranslation->{$TranslatedTo->{$1}} = $2;
				#$TranslatedTo->{$2} = $TranslatedTo->{$1};
			} else {
				#$RoleTranslation->{$1} = $2;
				#$TranslatedTo->{$2} = $1;
			}
		}
	}

	my $Count = 0;
	#Loading and adjusting chenry mappings
	my $MappingTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->{"Chris mapping filename"}->[0],"\t","",0,undef);
	for (my $i=0; $i < $MappingTable->size(); $i++) {
		my $Row = $MappingTable->get_row($i);
		if (defined($Row) && defined($Row->{"ROLE"}->[0]) && defined($RoleTranslation->{$Row->{"ROLE"}->[0]})) {
			$Count++;
			$Row->{"ROLE"}->[0] = $RoleTranslation->{$Row->{"ROLE"}->[0]};
		}
	}
	$MappingTable->save();
	print "Changes: ".$Count."\n";
	$Count = 0;
	#Loading the Hope mappings
	$MappingTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->{"Hope mapping filename"}->[0],"\t","",0,undef);
	for (my $i=0; $i < $MappingTable->size(); $i++) {
		my $Row = $MappingTable->get_row($i);
		if (defined($Row) && defined($Row->{"ROLE"}->[0]) && defined($RoleTranslation->{$Row->{"ROLE"}->[0]})) {
			$Count++;
			$Row->{"ROLE"}->[0] = $RoleTranslation->{$Row->{"ROLE"}->[0]};
		}
	}
	$MappingTable->save();
	print "Changes: ".$Count."\n";

	$self->CombineRoleReactionMappingSources();
}

=head3 GenerateSubsystemStats
Definition:
	FIGMODELTable:Table of subsystem statistics = $model->GenerateSubsystemStats(hashref:Hash of column headings with hashes of reactions)
Description:
Example:
=cut

sub GenerateSubsystemStats {
	my ($self,$ReactionListHash) = @_;

	my $SubsystemTable = ModelSEED::FIGMODEL::FIGMODELTable->new(["KEY","ID","TYPE","SUBSYSTEM","SUBSYSTEM CLASS 1","SUBSYSTEM CLASS 2"],"",["KEY"],";","|","");

	#Subsystem data will be stored in a hash
	my $SubsystemHash;
	my $Objects = ["SUBSYSTEM","SUBSYSTEM CLASS 1","SUBSYSTEM CLASS 2"];

	my @ColumnNames = keys(%{$ReactionListHash});
	foreach my $Heading (@ColumnNames) {
		#Adding column name to table
		$SubsystemTable->add_headings($Heading);
		#Calculating statistics
		my @ReactionList = keys(%{$ReactionListHash->{$Heading}});
		foreach my $Reaction (@ReactionList) {
			#Getting reaction subsystem from hash
			if (!defined($SubsystemHash->{$Reaction})) {
				#Filling in reaction subsystem data in the subsystem hash
				my $ReactionRow = $self->database()->GetLinkTable("REACTION","SUBSYSTEM")->get_row_by_key($Reaction,"REACTION");
				foreach my $Subsystem (@{$ReactionRow->{"SUBSYSTEM"}}) {
					my $ClassData = $self->class_of_subsystem($Subsystem);
					$Subsystem =~ s/;/,/;
					$ClassData->[0] =~ s/;/,/;
					$ClassData->[1] =~ s/;/,/;
					$SubsystemHash->{$Reaction}->{"SUBSYSTEM"}->{$Subsystem}->{"SUBSYSTEM"}->[0] = $Subsystem;
					$SubsystemHash->{$Reaction}->{"SUBSYSTEM"}->{$Subsystem}->{"SUBSYSTEM CLASS 1"}->[0] = $ClassData->[0];
					$SubsystemHash->{$Reaction}->{"SUBSYSTEM"}->{$Subsystem}->{"SUBSYSTEM CLASS 2"}->[0] = $ClassData->[1];
					push(@{$SubsystemHash->{$Reaction}->{"SUBSYSTEM CLASS 1"}->{$ClassData->[0]}->{"SUBSYSTEM"}},$Subsystem);
					$SubsystemHash->{$Reaction}->{"SUBSYSTEM CLASS 1"}->{$ClassData->[0]}->{"SUBSYSTEM CLASS 1"}->[0] = $ClassData->[0];
					push(@{$SubsystemHash->{$Reaction}->{"SUBSYSTEM CLASS 1"}->{$ClassData->[0]}->{"SUBSYSTEM CLASS 2"}},$ClassData->[1]);
					push(@{$SubsystemHash->{$Reaction}->{"SUBSYSTEM CLASS 2"}->{$ClassData->[1]}->{"SUBSYSTEM"}},$Subsystem);
					push(@{$SubsystemHash->{$Reaction}->{"SUBSYSTEM CLASS 2"}->{$ClassData->[1]}->{"SUBSYSTEM CLASS 1"}},$ClassData->[0]);
					$SubsystemHash->{$Reaction}->{"SUBSYSTEM CLASS 2"}->{$ClassData->[1]}->{"SUBSYSTEM CLASS 2"}->[0] = $ClassData->[1];
				}
			}
			#Adding data to the table
			foreach my $Object (@{$Objects}) {
				foreach my $ObjectID (keys(%{$SubsystemHash->{$Reaction}->{$Object}})) {
					my $ObjectInstance = $SubsystemHash->{$Reaction}->{$Object}->{$ObjectID};
					#Getting row for object from the table
					my $Row = $SubsystemTable->get_row_by_key($ObjectInstance->{$Object}->[0]."-".$Object,"KEY");
					if(!defined($Row)) {
						#Creating table row if it does not already exist
						$Row = {"KEY" => [$ObjectInstance->{$Object}->[0]."-".$Object],"ID" => [$ObjectInstance->{$Object}->[0]],"TYPE" => [$Object],"SUBSYSTEM" => $ObjectInstance->{"SUBSYSTEM"},"SUBSYSTEM CLASS 1" => $ObjectInstance->{"SUBSYSTEM CLASS 1"},"SUBSYSTEM CLASS 2" => $ObjectInstance->{"SUBSYSTEM CLASS 2"}};
						$SubsystemTable->add_row($Row);
					}
					#Updating the statistic in the table
					if (!defined($Row->{$Heading}->[0])) {
						$Row->{$Heading}->[0] = 0
					}
					$Row->{$Heading}->[0] += $ReactionListHash->{$Heading}->{$Reaction};
				}
			}
		}
	}

	return $SubsystemTable;
}

=head2 Public Methods: Perl API for interacting with the MFAToolkit c++ program

=head3 defaultParameters

Definition:
	{string:parameter => string:value} = FIGMODEL->defaultParameters();
Description:
	This function generates the default parameters for FBA

=cut

sub defaultParameters {
	my($self) = @_;
	my $DefaultParameters;
	my @parameters = keys(%{$self->config("default parameters")});
	for (my $i=0; $i < @parameters; $i++) {
		$DefaultParameters->{$parameters[$i]} = $self->config("default parameters")->{$parameters[$i]}->[0];	
	}
	return $DefaultParameters;
}

=head3 GenerateMFAToolkitCommandLineCall

Definition:
	my $CommandLine = $model->GenerateMFAToolkitCommandLineCall($UniqueFilename,$ModelName,$MediaName,$PrioritizedParameterFileList,$ParameterValueHash,$OutputLog,$RunType);

Description:
	This function formulates the command line required to call the MFAToolkit with the specified parameters

Example:
	$model->GenerateMFAToolkitCommandLineCall();

=cut

sub GenerateMFAToolkitCommandLineCall {
	my($self,$UniqueFilename,$ModelName,$MediaName,$ParameterFileList,$ParameterValueHash,$OutputLog,$RunType,$Version) = @_;

	#Adding the basic executable to the command line
	my $CommandLine = $self->{"MFAToolkit executable"}->[0];
	if (!defined($Version)) {
		$Version = "";
	}

	if (defined($ParameterFileList)) {
		#Adding the list of parameter files to the command line
		for (my $i=0; $i < @{$ParameterFileList}; $i++) {
			if ($ParameterFileList->[$i] =~ m/^\//) {
				$CommandLine .= " parameterfile ".$ParameterFileList->[$i];
			} else {
				$CommandLine .= " parameterfile ../Parameters/".$ParameterFileList->[$i].".txt";
			}
		}
	}

	#Dealing with the Media
	if (defined($MediaName) && length($MediaName) > 0 && $MediaName ne "NONE") {
		if ($MediaName eq "Complete" && $ModelName ne "Complete") {
			$CommandLine .= ' resetparameter "Default max drain flux" 10000 resetparameter "user bounds filename" "NoBounds.txt"';
		} elsif ($ModelName ne "Complete") {
			$CommandLine .= ' resetparameter "user bounds filename" "'.$MediaName.'.txt"';
		}
	}

	print $self->config("MFAToolkit output directory")->[0].$UniqueFilename."/\n";

	#Setting the output folder and the scratch folder
	if (defined($UniqueFilename) && length($UniqueFilename) > 0) {
		$CommandLine .= ' resetparameter output_folder "'.$UniqueFilename.'/"';
		if (!-d $self->config("MFAToolkit output directory")->[0].$UniqueFilename."/") {
			system("mkdir ".$self->config("MFAToolkit output directory")->[0].$UniqueFilename."/");
			system("mkdir ".$self->config("MFAToolkit output directory")->[0].$UniqueFilename."/scratch/");
			$ParameterValueHash->{"Network output location"} = $self->config("MFAToolkit output directory")->[0].$UniqueFilename."/scratch/";
		}else{
			system("mkdir ".$self->config("MFAToolkit output directory")->[0].$UniqueFilename."/scratch/");
			$ParameterValueHash->{"Network output location"} = $self->config("MFAToolkit output directory")->[0].$UniqueFilename."/scratch/";
		}
	}


	#Adding specific parameter value changes to the parameter list
	if (defined($ParameterValueHash)) {
		my @ChangedParameterNames = keys(%{$ParameterValueHash});
		for (my $i=0; $i < @ChangedParameterNames; $i++) {
			$CommandLine .= ' resetparameter "'.$ChangedParameterNames[$i].'" "'.$ParameterValueHash->{$ChangedParameterNames[$i]}.'"';
		}
	}

	#Completing model filename
	if (defined($ModelName) && $ModelName eq "processdatabase") {
		$CommandLine .= " ProcessDatabase";
	} elsif (defined($ModelName) && $ModelName eq "calculatetransatoms") {
		$CommandLine .= " CalculateTransAtoms";
	} elsif (!defined($ModelName) || length($ModelName) == 0 || $ModelName eq "NONE" || $ModelName eq "Complete") {
		if (defined($Version) && $Version =~ m/bio\d\d\d\d\d/) {
			if ($MediaName eq "Complete") {
				$CommandLine .= ' resetparameter "Default max drain flux" 10000 resetparameter "user bounds filename" "NoBounds.txt"';
				$CommandLine .= ' resetparameter "Max flux" 10000';
				$CommandLine .= ' resetparameter "Min flux" -10000';
			}
			$CommandLine .= ' resetparameter "Complete model biomass reaction" '.$Version;
			$CommandLine .= ' resetparameter "Make all reactions reversible in MFA" 1';
			$CommandLine .= ' resetparameter "dissapproved compartments" "'.$self->{"diapprovied compartments"}->[0].'"';
			$CommandLine .= ' resetparameter "Reactions to knockout" "'.$self->{"permanently knocked out reactions"}->[0].'"';
			$CommandLine .= ' resetparameter "Allowable unbalanced reactions" "'.$self->{"acceptable unbalanced reactions"}->[0].'"';
		}
		$CommandLine .= " LoadCentralSystem Complete";
	} elsif ($ModelName =~ m/\.txt/ || $ModelName =~ m/\.tbl/) {
		$CommandLine .= ' LoadCentralSystem "'.$ModelName.'"';
	} else {
		my $model = $self->get_model($ModelName.$Version);
		$CommandLine .= ' LoadCentralSystem "'.$model->filename().'"';
	}

	#Adding printing of output to a log file to the command line
	if (defined($OutputLog) && length($OutputLog) > 0 && $OutputLog ne "NONE") {
		if ($OutputLog =~ m/^\// || $OutputLog =~ m/^\w:/) {
			$CommandLine .= ' > "'.$OutputLog.'"';
		} else {
			$CommandLine .= ' > "'.$self->{"database message file directory"}->[0].$OutputLog.'"';
		}
	}

	#Dealing with the case where you want to run using qsub or nohup
	if (defined($RunType) && $RunType eq "NOHUP") {
		$CommandLine = "nohup ".$CommandLine." &";
	}
	$self->debug_message({
		function => "GenerateMFAToolkitCommandLineCall",
		message => $CommandLine,
		args => {}
	});
	return $CommandLine;
}

=head3 AdjustReactionDirectionalityInDatabase
Definition:
	success()/fail() = $model->AdjustReactionDirectionalityInDatabase(string::reaction,string::direction);
Description:
=cut
sub AdjustReactionDirectionalityInDatabase {
	my($self,$Reaction,$Direction) = @_;

	#Changing the reaction file
	my $Data = $self->LoadObject($Reaction);
	if (defined($Data->{EQUATION}->[0]) && $Data->{EQUATION}->[0] =~ m//) {
		$Data->{EQUATION}->[0] =~ s//$Direction/;
	}
	$self->SaveObject($Data);
	#Adding the reaction to the forced directionalities in figconfig
	my $data = $self->database()->load_single_column_file($self->config("database root directory")->[0]."ReactionDB/masterfiles/FIGMODELConfig.txt","");
	my $line;
	if ($Direction eq "<=>") {
		$line = "%corrections\\|";
	} elsif ($Direction eq "=>") {
		$line = "%forward\\sonly\\sreactions\\|";
	} elsif ($Direction eq "<=") {
		$line = "%reverse\\sonly\\sreactions\\|";
	}
	for (my $i=0; $i < @{$data}; $i++) {
		if ($data->[$i] =~ m/$line/ && $data->[$i] !~ m/$Reaction/) {
			$data->[$i] .= "|".$Reaction;
		}
	}
	$self->database()->print_array_to_file($self->config("database root directory")->[0]."ReactionDB/masterfiles/FIGMODELConfig.txt",$data);
	#Reseting directionality in the models
	for (my $i=0; $i < $self->number_of_models();$i++) {
		my $model = $self->get_model($i);
		if ($model->source() eq "SEED" || $model->source() eq "RAST" || $model->source() eq "MGRAST") {
			my $rxntbl = $model->reaction_table();
			if (defined($rxntbl)) {
				my $rxnobj = $rxntbl->get_row_by_key($Reaction,"LOAD");
				if (defined($rxnobj)) {
					$rxnobj->{"DIRECTIONALITY"}->[0] = $Direction;
				}
				$rxntbl->save();
				$model->PrintModelLPFile();
				#Testing model growth
				my $growth = $model->calculate_growth("Complete");
				if ($growth =~ m/NOGROWTH/) {
					#Gapfilling models that donot grow
					print "No growth in ".$model->id().". Rerunning gapfilling!\n";
					$model->GapFillModel(1);
				}
			}
		}
	}
}

=head3 RunFBASimulation
Definition:
	FIGMODELTable = $model->run_fba_study(string::study,reference to array of hash references::study parameters);
Description:
Example:
	$model->RunFBASimulation($ReactionKOSets,$GeneKOSets,$ModelList,$MediaList);
=cut
sub run_fba_study {
	my($self,$Study,$Hash) = @_;

	#Prepping arguments for FBA
	my ($Label,$RunType,$ReactionKOSets,$GeneKOSets,$ModelList,$MediaList);
	for (my $i=0; $i < @{$Hash}; $i++) {
		push(@{$RunType},$Study);
		push(@{$Label},$i);
		if (!defined($Hash->[$i]->{"reactionko"})) {
			push(@{$ReactionKOSets},["none"]);
		} else {
			if (ref($Hash->[$i]->{"reactionko"}) == "ARRAY") {
				push(@{$ReactionKOSets},$Hash->[$i]->{"reactionko"});
			} elsif ($Hash->[$i]->{"reactionko"} =~ m/,/) {
				push(@{$ReactionKOSets},split(/,/,$Hash->[$i]->{"reactionko"}));
			} else {
				push(@{$ReactionKOSets},[$Hash->[$i]->{"reactionko"}]);
			}
		}
		if (!defined($Hash->[$i]->{"geneko"})) {
			push(@{$GeneKOSets},["none"]);
		} else {
			if (ref($Hash->[$i]->{"geneko"}) == "ARRAY") {
				push(@{$GeneKOSets},$Hash->[$i]->{"geneko"});
			} elsif ($Hash->[$i]->{"geneko"} =~ m/,/) {
				push(@{$GeneKOSets},split(/,/,$Hash->[$i]->{"geneko"}));
			} else {
				push(@{$GeneKOSets},[$Hash->[$i]->{"geneko"}]);
			}
		}
		if (!defined($Hash->[$i]->{"media"})) {
			push(@{$MediaList},"Complete");
		} else {
			if (ref($Hash->[$i]->{"media"}) == "ARRAY") {
				push(@{$MediaList},@{$Hash->[$i]->{"media"}});
			} elsif ($Hash->[$i]->{"media"} =~ m/,/) {
				push(@{$MediaList},split(/,/,$Hash->[$i]->{"media"}));
			} else {
				push(@{$MediaList},$Hash->[$i]->{"media"});
			}
		}
		push(@{$ModelList},$Hash->[$i]->{"model"});
	}

	#Running FBA
	my $ResultTable = $self->RunFBASimulation($Label,$RunType,$ReactionKOSets,$GeneKOSets,$ModelList,$MediaList);

	return $ResultTable;
}

sub diagnose_unviable_strain {
	my($self,$Model,$strain,$media) = @_;
	#Getting the model
	my $model = $self->get_model($Model);
	if (!defined($model)) {
		return undef;
	}
	#Printing file with list of genes to be knocked out
	my $GeneList = $self->genes_of_strain($strain,$model->genome());
	if (!defined($GeneList)) {
		return undef;
	}
	#Running the mfatoolkit on this single condition
	my $UniqueFilename = $self->filename();
	PrintArrayToFile($self->config("MFAToolkit input files")->[0].$UniqueFilename."-deletion.txt",["ExperimentOne;GENES;".join(";",@{$GeneList})]);
	system($self->GenerateMFAToolkitCommandLineCall($UniqueFilename,$model->id().$model->selected_version(),$media,["ProductionMFA"],{"find coessential reactions for nonviable deletions" => "1","Force use variables for all reactions" => "1","Reactions use variables" => "1","optimize media when objective is zero" => "1","Add use variables for any drain fluxes" => "1","Force use variables for all drain fluxes" => "1","run deletion experiments" => "1","deletion experiment list file" => "MFAToolkitInputFiles/".$UniqueFilename."-deletion.txt"},"StrainViabilityStudy.txt"));
	if (!-e $self->config("MFAToolkit output directory")->[0].$UniqueFilename."/DeletionStudyResults.txt") {
		$self->error_message("FIGMODEL:diagnose_unviable_strain: Deletion study results data not found!");
		return undef;
	}
	#Loading results
	my $DeletionResultsTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->config("MFAToolkit output directory")->[0].$UniqueFilename."/DeletionStudyResults.txt",";","|",0,["Experiment"]);
	#Deleting gene list input
	#unlink($self->config("MFAToolkit input files")->[0].$UniqueFilename."-deletion.txt");
	#Clearing MFAToolkit output
	$self->clearing_output($UniqueFilename,"StrainViabilityStudy.txt");
	#Processing output
	my $results;
	if (defined($DeletionResultsTable->get_row(0)->{"Reactions"}->[0])) {
		push(@{$results->{"REACTIONS_DELETED"}},split(/,/,$DeletionResultsTable->get_row(0)->{"Reactions"}->[0]));
	}
	if (defined($DeletionResultsTable->get_row(0)->{"Genes"}->[0])) {
		push(@{$results->{"GENES_DELETED"}},split(/,/,$DeletionResultsTable->get_row(0)->{"Genes"}->[0]));
	}
	if (defined($DeletionResultsTable->get_row(0)->{"Restoring reaction sets"}->[0])) {
		$results->{"COESSENTIAL_REACTIONS"}->[0] = join("/",@{$DeletionResultsTable->get_row(0)->{"Restoring reaction sets"}});
	} else {
		$results->{"COESSENTIAL_REACTIONS"}->[0] = "NONE";
	}
	if (defined($DeletionResultsTable->get_row(0)->{"Additional media required"}->[0]) && $DeletionResultsTable->get_row(0)->{"Additional media required"}->[0] ne "No feasible media formulations") {
		$results->{"RESCUE_MEDIA"}->[0] = join("/",@{$DeletionResultsTable->get_row(0)->{"Additional media required"}});
	} else {
		$results->{"RESCUE_MEDIA"}->[0] = "NONE";
	}
	return $results;
}

=head3 GetEssentialityData
Definition:
	my $EssentialityData = $model->GetEssentialityData($GenomeID);
Description:
	Gets all of the essentiality data for the specified genome.
	Returns undef if no essentiality data is available.
Example:
	my $EssentialityData = $model->GetEssentialityData("83333.1");
=cut

sub GetEssentialityData {
	my($self,$GenomeID) = @_;

	if (!(-e $self->{"experimental data directory"}->[0].$GenomeID."/Essentiality.txt")) {
		return undef;
	}

	if (!defined($self->{"CACHE"}->{"Essentiality_".$GenomeID})) {
		$self->{"CACHE"}->{"Essentiality_".$GenomeID} = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->{"experimental data directory"}->[0].$GenomeID."/Essentiality.txt","\t","",0,["Gene","Media","Essentiality","Source"]);
	}

	return $self->{"CACHE"}->{"Essentiality_".$GenomeID};
}

=head3 ParseBiolog
Definition:
	$model->ParseBiolog();
Description:
Example:
	$model->ParseBiolog();
=cut

sub ParseBiolog {
	my($self) = @_;

	#Loading the current biolog table
	my $BiologDataTable = new ModelSEED::FIGMODEL::FIGMODELTable(["NUTRIENT","SEARCH NAME","NAME","PLATE ID","ORGANISM","GROWTH","SOURCE","MEDIA"],$self->{"Reaction database directory"}->[0]."masterfiles/BiologTable.txt",["NUTRIENT","SEARCH NAME","NAME","PLATE ID","MEDIA"],";","|","");

	#Getting the files with raw biolog data
	my $FileData = LoadSingleColumnFile($self->{"biolog raw data filename"}->[0],"");
	my $CurrentPlate = "";
	my @PlateNames;
	my $Nutrient = "";
	my $Source = "BIOLOG";
	my $Growth = 0;
	my $RowDone = 0;
	my $PlateSet = "";
	my $GenomeID = "";
	my $Data;
	foreach my $Line (@{$FileData}) {
		my @LineArray = split(/\s/,$Line);
		foreach my $LineData (@LineArray) {
			if (length($LineData) > 0) {
				push(@{$Data},$LineData);
			}
		}
	}
	for(my $i=0; $i < @{$Data};$i++) {
		if ($Data->[$i] eq "Carbon" || $Data->[$i] eq "Nitrogen" || $Data->[$i] eq "Sulfate" || $Data->[$i] eq "Phosphate") {
			if ($CurrentPlate ne "" || @PlateNames > 0) {
				$RowDone = 1;
				$i--;
			} else {
				$Nutrient = $Data->[$i];
			}
		} elsif ($Data->[$i] =~ m/^\d+\.\d+$/) {
			if ($CurrentPlate ne "" || @PlateNames > 0) {
				$RowDone = 1;
				$i--;
			} else {
				$GenomeID = $Data->[$i];
			}
		} elsif ($Data->[$i] eq "A00") {
			if ($CurrentPlate ne "" || @PlateNames > 0) {
				$RowDone = 1;
				$i--;
			}
		} elsif ($Data->[$i] =~ m/^(\d[A-Z]\d\d)$/) {
			if ($CurrentPlate ne "" || @PlateNames > 0) {
				$RowDone = 1;
				$i--;
			} else {
				$CurrentPlate = $1;
			}
		} elsif ($Data->[$i] =~ m/^(\d[A-Z])(\d)$/) {
			if ($CurrentPlate ne "" || @PlateNames > 0) {
				$RowDone = 1;
				$i--;
			} else {
				$CurrentPlate = $1."0".$2;
			}
		} elsif ($Data->[$i] =~ m/^([A-Z])(\d)$/) {
			if ($CurrentPlate ne "" || @PlateNames > 0) {
				$RowDone = 1;
				$i--;
			} else {
				$CurrentPlate = $PlateSet.$1."0".$2;
			}
		} elsif ($Data->[$i] =~ m/^([A-Z])(\d\d)$/) {
			if ($CurrentPlate ne "" || @PlateNames > 0) {
				$RowDone = 1;
				$i--;
			} else {
				$CurrentPlate = $PlateSet.$1.$2;
			}
		} elsif ($Data->[$i] =~ m/^(PMID\d+)$/) {
			if ($CurrentPlate ne "" || @PlateNames > 0) {
				$RowDone = 1;
				$i--;
			} else {
				$Source = $1;
			}
		} elsif ($Data->[$i] =~ m/^PM(\d)$/) {
			if ($CurrentPlate ne "" || @PlateNames > 0) {
				$RowDone = 1;
				$i--;
			} else {
				$PlateSet = $1;
			}
		} elsif ($Data->[$i] =~ m/^\+$/) {
			$Growth = 1;
			$RowDone = 1;
		} elsif ($Data->[$i] =~ m/^W$/) {
			$Growth = 0.5;
			$RowDone = 1;
		} elsif ($Data->[$i] =~ m/^-$/) {
			$Growth = 0;
			$RowDone = 1;
		} else {
			my @NewNames = split(/\|/,$Data->[$i]);
			if (@PlateNames > 0) {
				$PlateNames[@PlateNames-1] .= shift(@NewNames);
			}
			push(@PlateNames,@NewNames);
		}
		if ($RowDone == 1) {
			if (@PlateNames == 0 && $CurrentPlate eq "") {
				print STDERR "FIGMODEL:ParseBiolog: row found with no plate name or ID\n";
			} else {
				#Setting the nutrient based on the plate ID
				if ($CurrentPlate ne "") {
					if ($CurrentPlate =~ m/^[12]/) {
						$Nutrient = "Carbon";
					} elsif ($CurrentPlate =~ m/^3/) {
						$Nutrient = "Nitrogen";
					} elsif ($CurrentPlate =~ m/^4[ABCDE]/) {
						$Nutrient = "Phosphate";
					} else {
						$Nutrient = "Sulfate";
					}
				}
				#Checking that the plate has been assigned to a nutrient category
				if ($Nutrient eq "") {
					print STDERR "FIGMODEL:ParseBiolog: row found with no nutrient specification: ".join("|",@PlateNames).": ".$CurrentPlate."\n";
				} else {
					my $AddRow = 1;
					my @SearchNames;
					if ($CurrentPlate ne "") {
						my @MatchingRows = $BiologDataTable->get_rows_by_key($CurrentPlate,"PLATE ID");
						foreach my $Row (@MatchingRows) {
							if ($Row->{"ORGANISM"}->[0] eq $GenomeID) {
								$AddRow = 0;
								if (($Row->{"GROWTH"}->[0] > 0 && $Growth == 0) || ($Row->{"GROWTH"}->[0] == 0 && $Growth > 0)) {
									print STDERR "FIGMODEL:ParseBiolog: Growth mismatch in raw biolog data for plate ".$CurrentPlate.":".$GenomeID.": ".$Row->{"SOURCE"}->[0].":".$Row->{"GROWTH"}->[0]." vs ".$Source.":".$Growth."\n";
								}
							}
							#Checking if there is a plate ID conflict
							foreach my $OtherName (@{$Row->{"SEARCH NAME"}}) {
								my $Match = 0;
								foreach my $CurrentName (@SearchNames) {
									if ($CurrentName eq $OtherName) {
										$Match = 1;
										last;
									}
								}
								if ($Match == 0) {
									push(@SearchNames,$OtherName);
								}
							}
							foreach my $OtherName (@{$Row->{"NAME"}}) {
								my $Match = 0;
								foreach my $CurrentName (@PlateNames) {
									if ($CurrentName eq $OtherName) {
										$Match = 1;
										last;
									}
								}
								if ($Match == 0) {
									push(@PlateNames,$OtherName);
								}
							}
							foreach my $OtherName (@SearchNames) {
								$BiologDataTable->add_data($Row,"SEARCH NAME",$OtherName,1);
							}
							foreach my $OtherName (@PlateNames) {
								$BiologDataTable->add_data($Row,"NAME",$OtherName,1);
							}
						}
					}
					if (@PlateNames > 0) {
						#Handling the search names
						for (my $j=0; $j < @PlateNames; $j++) {
							push(@SearchNames,$self->ConvertToSearchNames($PlateNames[$j]));
						}
						#Data synchronization
						foreach my $Name (@SearchNames) {
							my @MatchingRows = $BiologDataTable->get_rows_by_key($Name,"SEARCH NAME");
							foreach my $Row (@MatchingRows) {
								#Checking that the nutrients match
								if (defined($Row->{"NUTRIENT"}) && $Row->{"NUTRIENT"}->[0] eq $Nutrient) {
									#Checking if there is a plate ID conflict
									my $Error = 0;
									if (defined($Row->{"PLATE ID"}) && $Row->{"PLATE ID"}->[0] ne "") {
										if ($CurrentPlate eq "") {
											$CurrentPlate = $Row->{"PLATE ID"}->[0];
										} elsif ($CurrentPlate ne $Row->{"PLATE ID"}->[0]) {
											print STDERR "FIGMODEL:ParseBiolog: missmatching plate IDs with the same search name: ".$CurrentPlate.":".$Row->{"PLATE ID"}->[0].":".$Name."\n";
											$Error = 1;
										}
									}
									#Adding any names or search names that may be missing
									if ($Error == 0) {
										foreach my $OtherName (@{$Row->{"SEARCH NAME"}}) {
											my $Match = 0;
											foreach my $CurrentName (@SearchNames) {
												if ($CurrentName eq $OtherName) {
													$Match = 1;
													last;
												}
											}
											if ($Match == 0) {
												push(@SearchNames,$OtherName);
											}
										}
										foreach my $OtherName (@{$Row->{"NAME"}}) {
											my $Match = 0;
											foreach my $CurrentName (@PlateNames) {
												if ($CurrentName eq $OtherName) {
													$Match = 1;
													last;
												}
											}
											if ($Match == 0) {
												push(@PlateNames,$OtherName);
											}
										}
										foreach my $OtherName (@SearchNames) {
											$BiologDataTable->add_data($Row,"SEARCH NAME",$OtherName,1);
										}
										foreach my $OtherName (@PlateNames) {
											$BiologDataTable->add_data($Row,"NAME",$OtherName,1);
										}
									}
								}
							}
						}
					}
					my $NameRef;
					my $SearchRef;
					push(@{$NameRef},@PlateNames);
					push(@{$SearchRef},@SearchNames);
					if ($AddRow == 1) {
						$BiologDataTable->add_row({"NUTRIENT" => [$Nutrient],"SEARCH NAME" => $SearchRef,"NAME" => $NameRef,"PLATE ID" => [$CurrentPlate],"ORGANISM" => [$GenomeID],"GROWTH" => [$Growth],"SOURCE" => [$Source]});
					}
				}
			}
			$RowDone = 0;
			@PlateNames = ();
			$CurrentPlate = "";
			$Growth = 0;
		}
	}

	#Lining media up with biolog nutrients
	my $MediaList = $self->GetListOfMedia();
	foreach my $Media (@{$MediaList}) {
		my $Nutrient = "";
		my $Name = "";
		if ($Media =~ m/Carbon-(.+)/) {
			$Nutrient = "Carbon";
			$Name = $1;
		} elsif ($Media =~ m/Nitrogen-(.+)/) {
			$Nutrient = "Nitrogen";
			$Name = $1;
		} elsif ($Media =~ m/Phosphate-(.+)/) {
			$Nutrient = "Phosphate";
			$Name = $1;
		} elsif ($Media =~ m/Sulfate-(.+)/) {
			$Nutrient = "Sulfate";
			$Name = $1;
		}
		if ($Nutrient ne "" && $Name ne "") {
			my @SearchNames = $self->ConvertToSearchNames($Name);
			my $Match = 0;
			for (my $i=0; $i < @SearchNames; $i++) {
				my @MatchingRows = $BiologDataTable->get_rows_by_key($SearchNames[$i],"SEARCH NAME");
				foreach my $Row (@MatchingRows) {
					#Checking that the nutrients match
					if (defined($Row->{"NUTRIENT"}) && $Row->{"NUTRIENT"}->[0] eq $Nutrient) {
						#Checking if there is a media conflict
						if (defined($Row->{"MEDIA"}) && $Row->{"MEDIA"}->[0] ne $Nutrient."-".$Name) {
							print STDERR "FIGMODEL:ParseBiolog: missmatching media IDs with the same search name: ".$Row->{"PLATE ID"}->[0].":".$Row->{"MEDIA"}->[0].":".$Nutrient."-".$Name."\n";
						} else {
							$Row->{"MEDIA"}->[0] = $Nutrient."-".$Name;
							$Match = 1;
							foreach my $OtherName (@SearchNames) {
								$BiologDataTable->add_data($Row,"SEARCH NAME",$OtherName,1);
							}
							$BiologDataTable->add_data($Row,"NAME",$Name,1);
						}
					}
				}
			}
			if ($Match == 0) {
				my $SearchRef;
				push(@{$SearchRef},@SearchNames);
				$BiologDataTable->add_row({"NUTRIENT" => [$Nutrient],"SEARCH NAME" => $SearchRef,"NAME" => [$Name],"MEDIA" => [$Nutrient."-".$Name]});
			}
		}
	}

	#Now we search for compounds to match the biolog names with no corresponding media
	my $MediaArray = LoadSingleColumnFile($self->{"Media directory"}->[0]."Carbon-D-Glucose.txt",";");
	my $CompoundTable = $self->database()->GetDBTable("COMPOUNDS");
	for (my $i=0; $i < $BiologDataTable->size(); $i++) {
		my $Row = $BiologDataTable->get_row($i);
		if (!defined($Row->{"MEDIA"}) || $Row->{"MEDIA"}->[0] eq "") {
			if (defined($Row->{"SEARCH NAME"})) {
				for (my $j=0; $j < @{$Row->{"SEARCH NAME"}}; $j++) {
					my $MatchingRow = $CompoundTable->get_row_by_key($Row->{"SEARCH NAME"}->[$j],"SEARCHNAME");
					if (defined($MatchingRow) && defined($MatchingRow->{"DATABASE"})) {
						$Row->{"MEDIA"}->[0] = $Row->{"NUTRIENT"}->[0]."-".$MatchingRow->{"NAME"}->[0];
						#Creating the media file for this biolog component if it does not already exist
						if (!(-e $self->{"Media directory"}->[0].$Row->{"NUTRIENT"}->[0]."-".$MatchingRow->{"NAME"}->[0].".txt")) {
							my $NewMedia;
							push(@{$NewMedia},@{$MediaArray});
							my $Database = $MatchingRow->{"DATABASE"}->[0];
							if ($Row->{"NUTRIENT"}->[0] eq "Carbon") {
								$NewMedia->[1] =~ s/cpd00027/$Database/;
							} elsif ($Row->{"NUTRIENT"}->[0] eq "Phosphate") {
								$NewMedia->[3] =~ s/cpd00009/$Database/;
							} elsif ($Row->{"NUTRIENT"}->[0] eq "Nitrogen") {
								$NewMedia->[2] =~ s/cpd00013/$Database/;
							} elsif ($Row->{"NUTRIENT"}->[0] eq "Sulfate") {
								$NewMedia->[4] =~ s/cpd00048/$Database/;
							}
							PrintArrayToFile($self->{"Media directory"}->[0].$Row->{"NUTRIENT"}->[0]."-".$MatchingRow->{"NAME"}->[0].".txt",$NewMedia)
						}
						last;
					}
				}
			}
		}
	}

	#Checking if there are still components with no media
	my %BiologComponentsWithNoMedia;
	for (my $i=0; $i < $BiologDataTable->size(); $i++) {
		my $Row = $BiologDataTable->get_row($i);
		if (!defined($Row->{"MEDIA"}) || $Row->{"MEDIA"}->[0] eq "") {
			$BiologComponentsWithNoMedia{$Row->{"NUTRIENT"}->[0]."-".$Row->{"NAME"}->[0]} = 1;
		}
	}
	#print "Biolog media components with no media formulation:\n";
	#print join("\n",keys(%BiologComponentsWithNoMedia))."\n";

	#Printing the culture files for every genome with data
	my %OrganismCultureListHash;
	for (my $i=0; $i < $BiologDataTable->size(); $i++) {
		my $Row = $BiologDataTable->get_row($i);
		if (defined($Row->{"MEDIA"}) && $Row->{"MEDIA"}->[0] ne "" && defined($Row->{"GROWTH"}) && defined($Row->{"SOURCE"}->[0])) {
			push(@{$OrganismCultureListHash{$Row->{"ORGANISM"}->[0]}},$Row->{"MEDIA"}->[0]."\t".$Row->{"GROWTH"}->[0]."\t".$Row->{"SOURCE"}->[0]);
		}
	}
	my @OrganismList = keys(%OrganismCultureListHash);
	for (my $i=0; $i < @OrganismList; $i++) {
		if (!(-d $self->{"experimental data directory"}->[0].$OrganismList[$i]."/")) {
			system("mkdir ".$self->{"experimental data directory"}->[0].$OrganismList[$i]."/");
		}
		my $NewCultureData = ["Media\tGrowth rate\tSource"];
		push(@{$NewCultureData},sort(@{$OrganismCultureListHash{$OrganismList[$i]}}));
		PrintArrayToFile($self->{"experimental data directory"}->[0].$OrganismList[$i]."/CultureConditions.txt",$NewCultureData);
	}

	#Getting the list of biolog compound IDs
	my $CompoundSymporter = new ModelSEED::FIGMODEL::FIGMODELTable(["NUTRIENT","SEARCH NAME","NAME","PLATE ID","ORGANISM","GROWTH","SOURCE","MEDIA"],$self->{"Reaction database directory"}->[0]."masterfiles/BiologTable.txt",["NUTRIENT","SEARCH NAME","NAME","PLATE ID","MEDIA"],";","|","");
	my %CompoundHash;
	for (my $i=0; $i < $BiologDataTable->size(); $i++) {
		my $Row = $BiologDataTable->get_row($i);
		if (defined($Row->{"MEDIA"}) && -e $self->{"Media directory"}->[0].$Row->{"MEDIA"}->[0].".txt") {
			my $MediaTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->{"Media directory"}->[0].$Row->{"MEDIA"}->[0].".txt",";","",0,["VarName"]);
			if ($Row->{"NUTRIENT"}->[0] eq "Carbon") {
				$CompoundHash{$MediaTable->get_row(0)->{"VarName"}->[0]}->{$Row->{"MEDIA"}->[0]} = 1;
			} elsif ($Row->{"NUTRIENT"}->[0] eq "Nitrogen") {
				$CompoundHash{$MediaTable->get_row(1)->{"VarName"}->[0]}->{$Row->{"MEDIA"}->[0]} = 1;
			} elsif ($Row->{"NUTRIENT"}->[0] eq "Sulfate") {
				$CompoundHash{$MediaTable->get_row(3)->{"VarName"}->[0]}->{$Row->{"MEDIA"}->[0]} = 1;
			} elsif ($Row->{"NUTRIENT"}->[0] eq "Phosphate") {
				$CompoundHash{$MediaTable->get_row(2)->{"VarName"}->[0]}->{$Row->{"MEDIA"}->[0]} = 1;
			}
		}
	}
	#Now checking if a proton sympoter exists for each of the biolog components
	my $BiologTransporterTable = new ModelSEED::FIGMODEL::FIGMODELTable(["COMPOUND","REACTION","MEDIA"],$self->{"Reaction database directory"}->[0]."masterfiles/BiologTransporters.txt",["COMPOUND","REACTION","MEDIA"],";","|","");
	my @CompoundList = keys(%CompoundHash);
	my $ReactionTable = $self->database()->GetDBTable("REACTIONS");
	my @ReactionList;
	for (my $i=0; $i < $ReactionTable->size(); $i++) {
		if ($ReactionTable->get_row($i)->{"DATABASE"}->[0] =~ m/(rxn\d\d\d\d\d)/) {
			push(@ReactionList,$1);
		}
	}
	@ReactionList = sort(@ReactionList);
	my $CurrentRxnID = $ReactionList[@ReactionList-1];
	$CurrentRxnID++;
	foreach my $Compound (@CompoundList) {
		my $Search = $Compound."\\[e\\]";
		my $MediaArray;
		push(@{$MediaArray},keys(%{$CompoundHash{$Compound}}));
		for (my $i=0; $i < $ReactionTable->size(); $i++) {
			if ($ReactionTable->get_row($i)->{"EQUATION"}->[0] =~ m/$Search/i && $ReactionTable->get_row($i)->{"EQUATION"}->[0] =~ m/cpd00067\[e\]/i && $ReactionTable->get_row($i)->{"EQUATION"}->[0] !~ m/\[p\]/i) {
				$BiologTransporterTable->add_row({"COMPOUND" => [$Compound],"REACTION" => [$ReactionTable->get_row($i)->{"DATABASE"}->[0]],"MEDIA" => $MediaArray});
				last;
			}
		}
		if (!defined($BiologTransporterTable->get_row_by_key($Compound,"COMPOUND"))) {
			my $NewObject = ModelSEED::FIGMODEL::FIGMODELObject->new(["DATABASE","NAME","EQUATION","PATHWAY","DELTAG","DELTAGERR","THERMODYNAMIC REVERSIBILITY"],$self->{"reaction directory"}->[0].$CurrentRxnID,"\t");
			my $CompoundRow = $CompoundTable->get_row_by_key($Compound,"DATABASE");
			$NewObject->add_data([$CurrentRxnID],"DATABASE");
			my $TransportType = "symport";
			my $ReactHComp = "[e]";
			my $ProdHComp = "";
			my $HCoeff = "";
			if (defined($CompoundRow->{"CHARGE"}->[0])) {
				if ($CompoundRow->{"CHARGE"}->[0] > 0) {
					$TransportType = "antiport";
					$ReactHComp = "";
					$ProdHComp = "[e]";
				}
				if (abs($CompoundRow->{"CHARGE"}->[0]) > 1) {
					$HCoeff = abs($CompoundRow->{"CHARGE"}->[0])." ";
				}
			}
			$NewObject->add_data([$HCoeff."cpd00067".$ReactHComp." + ".$Compound."[e] <=> ".$Compound." + ".$HCoeff."cpd00067".$ProdHComp],"EQUATION");
			$NewObject->add_data(["Transport"],"PATHWAY");
			$NewObject->add_data(["0"],"DELTAG");
			$NewObject->add_data(["0"],"DELTAGERR");
			$NewObject->add_data(["<=>"],"THERMODYNAMIC REVERSIBILITY");
			if (defined($CompoundRow->{"NAME"}->[0])) {
				$NewObject->add_data([$CompoundRow->{"NAME"}->[0]." transport via proton ".$TransportType],"NAME");
			}
			$NewObject->save();
			$BiologTransporterTable->add_row({"COMPOUND" => [$Compound],"REACTION" => [$CurrentRxnID],"MEDIA" => $MediaArray});
			$CurrentRxnID++;
		}
	}
	$BiologTransporterTable->save();

	#Printing the table to file
	$BiologDataTable->save();
}

=head3 GetCultureData
Definition:
	my $CultureData = $model->GetCultureData($GenomeID);
Description:
	Gets all of the culture data for the specified genome.
	Returns undef if no culture data is available.
Example:
	my $CultureData = $model->GetCultureData("83333.1");
=cut

sub GetCultureData {
	my($self,$GenomeID) = @_;

	if (!(-e $self->{"experimental data directory"}->[0].$GenomeID."/CultureConditions.txt")) {
		return undef;
	}

	if (!defined($self->{"CACHE"}->{"CultureConditions_".$GenomeID})) {
		$self->{"CACHE"}->{"CultureConditions_".$GenomeID} = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->{"experimental data directory"}->[0].$GenomeID."/CultureConditions.txt","\t","",0,["Media"]);
	}

	return $self->{"CACHE"}->{"CultureConditions_".$GenomeID};
}

=head3 GetIntervalEssentialityData
Definition:
	my $IntervalEssentialityData = $model->GetIntervalEssentialityData($GenomeID);
Description:
	Gets all of the interval essentiality data for the specified genome.
	Returns undef if no interval essentiality data is available.
Example:
	my $IntervalEssentialityData = $model->GetIntervalEssentialityData("83333.1");
=cut

sub GetIntervalEssentialityData {
	my($self,$GenomeID) = @_;

	if (!(-e $self->{"experimental data directory"}->[0].$GenomeID."/IntervalEssentiality.txt")) {
		return undef;
	}

	if (!defined($self->{"CACHE"}->{"IntervalEssentiality_".$GenomeID})) {
		$self->{"CACHE"}->{"IntervalEssentiality_".$GenomeID} = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->{"experimental data directory"}->[0].$GenomeID."/IntervalEssentiality.txt","\t","",0,["Media"]);
	}

	return $self->{"CACHE"}->{"IntervalEssentiality_".$GenomeID};
}

=head3 PredictEssentialGenes
Definition:
	my $Results = $model->PredictEssentialGenes($Model,$Media);
Description:
	This function predicts the essential genes in an organism using the specified model in the specified media.
	The function returns a reference to a hash of the predicted essential genes.
	If for some reason the study fails, the function returns undef.
Example:
	my $Results = $model->PredictEssentialGenes("Seed100226.1","ArgonneLBMedia");
=cut

sub PredictEssentialGenes {
	my($self,$ModelName,$Media,$Classify,$Version,$Solver) = @_;

	if (!defined($Solver)) {
		$Solver = "GLPK";
	}
	if (!defined($Version)) {
		$Version = "";
	}

	if (!defined($Media) ||  $Media eq "") {
		$Media = "Complete";
	}

	my $UniqueFilename = $self->filename();
	if (defined($Classify) && $Classify == 1) {
		system($self->GenerateMFAToolkitCommandLineCall($UniqueFilename,$ModelName,$Media,["ProductionMFA"],{"perform single KO experiments" => "1","find tight bounds" => "1","MFASolver" => $Solver},"EssentialityPrediction-".$ModelName.$Version."-".$UniqueFilename.".txt",undef,$Version));
	} else {
		system($self->GenerateMFAToolkitCommandLineCall($UniqueFilename,$ModelName,$Media,["ProductionMFA"],{"perform single KO experiments" => "1","MFASolver" => $Solver},"EssentialityPrediction-".$ModelName.$Version."-".$UniqueFilename.".txt",undef,$Version));
	}

	my $DeletionResultsTable;
	if (-e $self->{"MFAToolkit output directory"}->[0].$UniqueFilename."/DeletionStudyResults.txt") {
		$DeletionResultsTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->{"MFAToolkit output directory"}->[0].$UniqueFilename."/DeletionStudyResults.txt",";",",",0,["Experiment"]);
	} else {
		print STDERR "FIGMODEL:PredictEssentialGenes: Deletion study results data not found!\n";
		return undef;
	}

	#If the system is not configured to preserve all logfiles, then the output printout from the mfatoolkit is deleted
	if ($self->{"preserve all log files"}->[0] eq "no") {
		unlink($self->{"database message file directory"}->[0]."EssentialityPrediction-".$ModelName.$Version."-".$UniqueFilename.".txt");
		$self->cleardirectory($UniqueFilename);
	}

	return $DeletionResultsTable;
}

=head3 PredictEssentialIntervals
Definition:
	my $Results = $model->PredictEssentialIntervals($self,$ModelName,$IntervalIDs,$Coordinates,$Growth,$Media,$Classify);
Description:
	This function predicts the essentiality of specified gene intervals in an organism using the specified model in the specified media.
	The function returns a table of the results from the deletion study.
	If for some reason the study fails, the function returns undef.
Example:
	my $Results = $model->PredictEssentialIntervals("Seed100226.1",{"A" => "10000_50000"},"ArgonneLBMedia");
=cut

sub PredictEssentialIntervals {
	my($self,$ModelName,$IntervalIDs,$Coordinates,$Growth,$Media,$Classify,$Version,$Solver) = @_;

	if (!defined($Solver)) {
		$Solver = "";
	}
	if (!defined($Version)) {
		$Version = "";
	}

	if (!defined($Media) ||  $Media eq "") {
		$Media = "Complete";
	}

	#Writing the interval definition file for this media condition
	my $UniqueFilename = $self->filename();
	my $IntervalOutputFilename = $self->{"MFAToolkit input files"}->[0]."Int".$UniqueFilename.".txt";
	if (open (OUTPUT, ">$IntervalOutputFilename")) {
		for (my $j=0; $j < @{$IntervalIDs}; $j++) {
			print OUTPUT $Coordinates->[$j]."\t".$IntervalIDs->[$j]."\t".$Growth->[$j]."\n";
		}
		close(OUTPUT);
	}

	if (defined($Classify) && $Classify == 1) {
		system($self->GenerateMFAToolkitCommandLineCall($UniqueFilename,$ModelName,$Media,["IntervalDeletions"],{"interval experiment list file" => "MFAToolkitInputFiles/Int".$UniqueFilename.".txt","find tight bounds" => "1","MFASolver" => $Solver},"IntervalPrediction-".$ModelName.$Version."-".$UniqueFilename.".txt",undef,$Version));
	} else {
		system($self->GenerateMFAToolkitCommandLineCall($UniqueFilename,$ModelName,$Media,["IntervalDeletions"],{"interval experiment list file" => "MFAToolkitInputFiles/Int".$UniqueFilename.".txt","MFASolver" => $Solver},"IntervalPrediction-".$ModelName.$Version."-".$UniqueFilename.".txt",undef,$Version));
	}
	unlink($IntervalOutputFilename);

	my $DeletionResultsTable;
	if (-e $self->{"MFAToolkit output directory"}->[0].$UniqueFilename."/DeletionStudyResults.txt") {
		$DeletionResultsTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->{"MFAToolkit output directory"}->[0].$UniqueFilename."/DeletionStudyResults.txt",";",",",0,["Experiment"]);
	} else {
		print STDERR "FIGMODEL:PredictEssentialGenes: Deletion study results data not found!\n";
		return undef;
	}

	#If the system is not configured to preserve all logfiles, then the output printout from the mfatoolkit is deleted
	if ($self->{"preserve all log files"}->[0] eq "no") {
		unlink($self->{"database message file directory"}->[0]."IntervalPrediction-".$ModelName.$Version."-".$UniqueFilename.".txt");
		$self->cleardirectory($UniqueFilename);
	}
	return $DeletionResultsTable;
}

=head3 GetExperimentalDataTable
Definition:
	my $DataTable = GetExperimentalDataTable($Genome,$Experiment);
Description:
Example:
	my $DataTable = GetExperimentalDataTable($Genome,$Experiment);
=cut

sub GetExperimentalDataTable {
	my ($self,$GenomeID,$Experiment) = @_;

	#Specifying gene KO simulations
	my $ExperimentalDataTable = ModelSEED::FIGMODEL::FIGMODELTable->new(["Heading","Experiment type","Media","Experiment ID","Growth"],"Temp.txt",["Heading"],";",",",undef);
	if ($Experiment eq "GeneKO" || $Experiment eq "All") {
		#Getting the table of experimentally determined essential genes
		my $ExperimentalEssentialGenes = $self->GetEssentialityData($GenomeID);
		if (!defined($ExperimentalEssentialGenes)) {
			print "FIGMODEL:RunGeneKOStudy: No experimental essentiality data found for the specified model!\n";
		} else {
			#Getting the list of media for which essentiality data is available
			my @MediaList = $ExperimentalEssentialGenes->get_hash_column_keys("Media");
			if (@MediaList == 0) {
				print STDERR "FIGMODEL:RunGeneKOStudy: No media conditions found for experimental essentiality data!\n";
			}
			#Populating the experimental data table
			for (my $i=0; $i < $ExperimentalEssentialGenes->size(); $i++) {
				if ($ExperimentalEssentialGenes->get_row($i)->{"Essentiality"}->[0] eq "essential") {
					$ExperimentalDataTable->add_row({"Heading" => ["Gene KO:".$ExperimentalEssentialGenes->get_row($i)->{"Media"}->[0].":".$ExperimentalEssentialGenes->get_row($i)->{"Gene"}->[0]],"Experiment type" => ["Gene KO"],"Media" => [$ExperimentalEssentialGenes->get_row($i)->{"Media"}->[0]],"Experiment ID" => [$ExperimentalEssentialGenes->get_row($i)->{"Gene"}->[0]],"Growth" => [0]});
				} elsif ($ExperimentalEssentialGenes->get_row($i)->{"Essentiality"}->[0] eq "nonessential") {
					$ExperimentalDataTable->add_row({"Heading" => ["Gene KO:".$ExperimentalEssentialGenes->get_row($i)->{"Media"}->[0].":".$ExperimentalEssentialGenes->get_row($i)->{"Gene"}->[0]],"Experiment type" => ["Gene KO"],"Media" => [$ExperimentalEssentialGenes->get_row($i)->{"Media"}->[0]],"Experiment ID" => [$ExperimentalEssentialGenes->get_row($i)->{"Gene"}->[0]],"Growth" => [1]});
				}
			}
		}
	}

	#Specifying media simulations
	if ($Experiment eq "Media" || $Experiment eq "All") {
		my $ExperimentCultureConditions = $self->GetCultureData($GenomeID);
		if (!defined($ExperimentCultureConditions)) {
			print "FIGMODEL:RunMediaGrowthStudy: No experimental culture data found for the specified model!\n";
		} else {
			my @MediaList;
			for (my $i=0; $i < $ExperimentCultureConditions->size(); $i++) {
				if (-e $self->{"Media directory"}->[0].$ExperimentCultureConditions->get_row($i)->{"Media"}->[0].".txt") {
					push(@MediaList,$ExperimentCultureConditions->get_row($i)->{"Media"}->[0]);
					$ExperimentalDataTable->add_row({"Heading" => ["Media growth:".$ExperimentCultureConditions->get_row($i)->{"Media"}->[0].":".$ExperimentCultureConditions->get_row($i)->{"Media"}->[0]],"Experiment type" => ["Media growth"],"Media" => [$ExperimentCultureConditions->get_row($i)->{"Media"}->[0]],"Experiment ID" => [$ExperimentCultureConditions->get_row($i)->{"Media"}->[0]],"Growth" => [$ExperimentCultureConditions->get_row($i)->{"Growth rate"}->[0]]});
				}
			}
		}
	}

	#Specifying interval KO simulations
	if ($Experiment eq "IntKO" || $Experiment eq "All") {
		#Getting the table of experimentally determined essential genes
		my $ExperimentalIntervals = $self->GetIntervalEssentialityData($GenomeID);
		if (!defined($ExperimentalIntervals)) {
			print "FIGMODEL:RunGeneKOStudy: No experimental interval essentiality data found for the specified model!\n";
		} else {
			my @MediaList = $ExperimentalIntervals->get_hash_column_keys("Media");
			if (@MediaList == 0) {
				print STDERR "FIGMODEL:RunIntervalKOStudy: No media conditions found for experimental essentiality data!\n";
			}
			#Getting gene list
			my $GeneTable = $self->GetGenomeFeatureTable($GenomeID);
			for (my $i=0; $i < @MediaList; $i++) {
				my @Rows = $ExperimentalIntervals->get_rows_by_key($MediaList[$i],"Media");
				foreach my $EssentialityData (@Rows) {
					my @Temp = split(/_/,$EssentialityData->{"Coordinates"}->[0]);
					if (@Temp >= 2) {
						#Determining gene KO from interval coordinates
						my $GeneKOSets = "";
						for (my $j=0; $j < $GeneTable->size(); $j++) {
							my $Row = $GeneTable->get_row($j);
							if ($Row->{"MIN LOCATION"}->[0] < $Temp[1] && $Row->{"MAX LOCATION"}->[0] > $Temp[0]) {
								if ($Row->{"ID"}->[0] =~ m/(peg\.\d+)/) {
									if (length($GeneKOSets) > 0) {
										$GeneKOSets = $GeneKOSets.",";
									}
									$GeneKOSets = $GeneKOSets.$1;
								}
							}
						}
						#Adding row to table of experimental data
						$ExperimentalDataTable->add_row({"Heading" => ["Interval KO:".$MediaList[$i].":".$EssentialityData->{"ID"}->[0]],"Experiment type" => [$GeneKOSets],"Media" => [$MediaList[$i]],"Experiment ID" => [$EssentialityData->{"ID"}->[0]],"Growth" => [$EssentialityData->{"Growth rate"}->[0]]});
					}
				}
			}
		}
	}

	return $ExperimentalDataTable;
}

=head3 GenerateJobFileLine
Definition:
	FIGMODELTable row::Job file row = $model->GenerateJobFileLine(string::Label,string::Model ID,string arrayref::Media list,string::Run type,0 or 1::Save fluxes,0 or 1::Save nonessential gene list);
Description:
Example:
=cut

sub GenerateJobFileLine {
	my ($self,$Label,$ModelID,$MediaList,$RunType,$SaveFluxes,$SaveNoness) = @_;

	my $modelObj = $self->get_model($ModelID);
	if (!defined($modelObj) || !-e $modelObj->directory().$ModelID.".txt" || !-e $modelObj->directory()."FBA-".$ModelID.".lp" || !-e $modelObj->directory()."FBA-".$ModelID.".key") {
		print STDERR "FIGMODEL:GenerateJobFileLine: Could not load ".$ModelID."\n";
		return undef;
	}

	return {"LABEL" => [$Label],"RUNTYPE" => [$RunType],"MEDIA" => [join("|",@{$MediaList})],"MODEL" => [$modelObj->directory().$ModelID.".txt"],"LP FILE" => [$modelObj->directory()."FBA-".$ModelID],"SAVE FLUXES" => [$SaveFluxes],"SAVE NONESSENTIALS" => [$SaveNoness]};
}

=head2 Marvin Beans Interaction Functions

=head3 add_pk_data_to_compound
Definition:
	int::status = FIGMODEL->add_pk_data_to_compound(string::ID || [string]::ID);
Description:
	Adds PkA and PkB data to compounds in database using marvin beans software
	Returns FIGMODEL status messages.
	Molfile must be available for compound
=cut

sub add_pk_data_to_compound {
	my ($self,$id,$save) = @_;

	#Checking if id is array or string
	if (ref($id) eq 'ARRAY') {
		for (my $i=0; $i < @{$id}; $i++) {
			$self->add_pk_data_to_compound($id->[$i]);
		}
		return $self->config("SUCCESS")->[0];
	#You have the option of specifying the id "ALL" and having this function process the whole database
	} elsif ($id eq "ALL") {
		my $List;
		my $CompoundTable = $self->database()->GetDBTable("COMPOUNDS");
		for (my $i=0; $i < $CompoundTable->size(); $i++) {
			push(@{$List},$CompoundTable->get_row($i)->{"DATABASE"}->[0]);
		}
		$self->add_pk_data_to_compound($List);
	}

	#Trying to get compound data from database
	my $data = $self->database()->get_row_by_key("COMPOUNDS",$id,"DATABASE");;
	if (!defined($data)) {
		print STDERR "FIGMODEL:add_pk_data_to_compound:Could not load ".$id." from database\n";
		return $self->config("FAIL")->[0];
	}

	#Checking that a molfile is available for compound
	if (!-e $self->config("Argonne molfile directory")->[0].$id.".mol") {
		print STDERR "FIGMODEL:add_pk_data_to_compound:Molfile not found for ".$id."\n";
		return $self->config("FAIL")->[0];
	}

	#Running marvin
	print STDOUT "Now processing ".$id."\n";
	system($self->config("marvinbeans executable")->[0].' '.$self->config("Argonne molfile directory")->[0].$id.".mol".' -i ID pka -a 6 -b 6 > '.$self->config("temp file directory")->[0].'pk'.$id.'.txt');

	#Checking that output file was generated
	if (!-e $self->config("temp file directory")->[0].'pk'.$id.'.txt') {
		print STDERR "FIGMODEL:add_pk_data_to_compound:Marvinbeans output file not generated for ".$id."\n";
		return $self->config("FAIL")->[0];
	}

	#Parsing output file and placing data in compound object
	my $pkdata = LoadMultipleColumnFile($self->config("temp file directory")->[0].'pk'.$id.'.txt',"\t");
	if (defined($pkdata->[1]) && defined($pkdata->[1]->[13])) {
		#print "SUCCESS!\n";
		my $CompoundObject = FIGMODELObject->load($self->config("compound directory")->[0].$id,"\t");
		delete $CompoundObject->{"PKA"};
		delete $CompoundObject->{"PKB"};
		my @Atoms = split(",",$pkdata->[1]->[13]);
		my $Count = 0;
		for (my $j=0; $j < 6; $j++) {
			if (defined($pkdata->[1]->[1+$j]) && length($pkdata->[1]->[1+$j]) > 0) {
				$CompoundObject->add_headings("PKA");
				$CompoundObject->add_data([$pkdata->[1]->[1+$j].":".$Atoms[$Count]],"PKA",1);
				#print "pKa:".$pkdata->[1]->[1+$j].":".$Atoms[$Count]."\n";
				$Count++;
			}
		}
		for (my $j=0; $j < 6; $j++) {
			if (defined($pkdata->[1]->[7+$j]) && length($pkdata->[1]->[7+$j]) > 0) {
				$CompoundObject->add_headings("PKB");
				$CompoundObject->add_data([$pkdata->[1]->[7+$j].":".$Atoms[$Count]],"PKB",1);
				#print "pKb:".$pkdata->[1]->[7+$j].":".$Atoms[$Count]."\n";
				$Count++;
			}
		}
		$CompoundObject->save();
	}
	unlink($self->config("temp file directory")->[0].'pk'.$id.'.txt');
}

=head3 PrintDatabaseLPFiles
Definition:
	$model->PrintDatabaseLPFiles();
Description:
	This algorithm prints LP files formulating various FBA algorithms on the entire database. This includes:
	1.) An LP file for standard fba on complete media with bounds of 100.
	2.) An LP file for gapfilling with use variables on complete media with bounds of 10000.
	3.) A TMFA LP on complete medai with bounds of 100.
	These LP files are used to do very fast database minimal fba using our mpifba code.
Example:
	$model->PrintDatabaseLPFiles();
=cut

sub PrintDatabaseLPFiles {
	my ($self) = @_;

	#Printing the standard FBA file
	system($self->GenerateMFAToolkitCommandLineCall("DatabaseProcessing","Complete","NoBounds",["ProdFullFBALP"],undef,"FBA_LP_Printing.log",undef,undef));
	system("cp ".$self->{"MFAToolkit output directory"}->[0]."DatabaseProcessing/CurrentProblem.lp ".$self->{"Reaction database directory"}->[0]."masterfiles/FBA.lp");
	#The variable keys are too large for distribution in parallel, so we load them and only save the portions with the data we need
	my $KeyTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->{"MFAToolkit output directory"}->[0]."DatabaseProcessing/VariableKey.txt",";","|",0,undef);
	$KeyTable->headings(["Variable type","Variable ID"]);
	$KeyTable->save($self->{"Reaction database directory"}->[0]."masterfiles/FBA.key");

	#Printing the gap filling FBA file
	system($self->GenerateMFAToolkitCommandLineCall("DatabaseProcessing","Complete","NoBounds",["ProdFullGapFillingLP"],undef,"GapFill_LP_Printing.log",undef,undef));
	system("cp ".$self->{"MFAToolkit output directory"}->[0]."DatabaseProcessing/CurrentProblem.lp ".$self->{"Reaction database directory"}->[0]."masterfiles/GapFill.lp");
	$KeyTable = undef;
	$KeyTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->{"MFAToolkit output directory"}->[0]."DatabaseProcessing/VariableKey.txt",";","|",0,undef);
	$KeyTable->headings(["Variable type","Variable ID"]);
	$KeyTable->save($self->{"Reaction database directory"}->[0]."masterfiles/GapFill.key");

	#Printing the TMFA file
	system($self->GenerateMFAToolkitCommandLineCall("DatabaseProcessing","Complete","NoBounds",["ProdFullTMFALP"],undef,"TMFA_LP_Printing.log",undef,undef));
	system("cp ".$self->{"MFAToolkit output directory"}->[0]."DatabaseProcessing/CurrentProblem.lp ".$self->{"Reaction database directory"}->[0]."masterfiles/TMFA.lp");
	$KeyTable = undef;
	$KeyTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->{"MFAToolkit output directory"}->[0]."DatabaseProcessing/VariableKey.txt",";","|",0,undef);
	$KeyTable->headings(["Variable type","Variable ID"]);
	$KeyTable->save($self->{"Reaction database directory"}->[0]."masterfiles/TMFA.key");
}

=head3 PrintModelGapFillObjective
Definition:
	$model->PrintModelGapFillObjective($Model);
Description:
	This algorithm prints the coefficients and variable names for all terms in the gap filling object for use with fbalite
Example:
	$model->PrintModelGapFillObjective("Seed83333.1");
=cut

sub PrintModelGapFillObjective {
	my ($self,$Model) = @_;

	#Getting filename
	my $Filename = $self->filename();

	#Printing the standard FBA file
	system($self->GenerateMFAToolkitCommandLineCall($Filename,$Model,"NoBounds",["ProductionPrintGFObj"],undef,$Model."-ProductionPrintGFObj.log",undef,undef));

	#Clearing the filename
	$self->cleardirectory($Filename);
}

=head3 CreateJobTable
Definition:
	$model->CreateJobTable($Folder);
Description:
Example:
	$model->CreateJobTable($Folder);
=cut

sub CreateJobTable {
	my ($self,$Folder) = @_;

	my $JobTable = ModelSEED::FIGMODEL::FIGMODELTable->new(["LABEL","RUNTYPE","LP FILE","MODEL","MEDIA","REACTION KO","REACTION ADDITION","GENE KO","SAVE FLUXES","SAVE NONESSENTIALS"],$self->{"MFAToolkit output directory"}->[0].$Folder."/Jobfile.txt",["LABEL"],";","|",undef);

	return $JobTable;
}

=head3 TestSolutions
Definition:
	$model->TestSolutions($ModelID,$NumProcessors,$ProcessorIndex,$GapFill);
Description:
Example:
=cut

sub TestSolutions {
	my ($self,$ModelID,$NumProcessors,$ProcessorIndex,$GapFill) = @_;

	my $model = $self->get_model($ModelID);
	#Getting unique filename
	$self->{"preserve all log files"}->[0] = "no";
	my $Filename = $self->filename();

	#This is the scheduler code
	if ($ProcessorIndex == -1 && -e $model->directory().$model->id().$model->selected_version()."-".$GapFill."S.txt") {
		#Updating the growmatch table
		my $GrowMatchTable = $self->database()->LockDBTable("GROWMATCH TABLE");
		my $Row = $GrowMatchTable->get_row_by_key($model->genome(),"ORGANISM",1);
		if ($GapFill eq "GF" || $GapFill eq "GG") {
			$Row->{$GapFill." TESTING TIMING"}->[0] = time()."-";
			$Row->{$GapFill." SOLUTIONS TESTED"}->[0] = CountFileLines($model->directory().$model->id().$model->selected_version()."-".$GapFill."S.txt")-1;
		}
		$GrowMatchTable->save();
		$self->database()->UnlockDBTable("GROWMATCH TABLE");

		#Adding all the subprocesses to the scheduler queue
		my $ProcessList;
		if (-e $model->directory().$model->id().$model->selected_version()."-".$GapFill."Error-0.txt") {
			unlink($model->directory().$model->id().$model->selected_version()."-".$GapFill."Error-0.txt");
		}
		for (my $i=1; $i < $NumProcessors; $i++) {
			if (-e $model->directory().$model->id().$model->selected_version()."-".$GapFill."Error-".$i.".txt") {
				unlink($model->directory().$model->id().$model->selected_version()."-".$GapFill."Error-".$i.".txt");
			}
			push(@{$ProcessList},"testsolutions?".$model->id().$model->selected_version()."?".$i."?".$GapFill."?".$NumProcessors);
		}
		PrintArrayToFile($self->{"temp file directory"}->[0]."SolutionTestQueue-".$model->id().$model->selected_version()."-".$Filename.".txt",$ProcessList);
		system($self->{"scheduler executable"}->[0]." \"add:".$self->{"temp file directory"}->[0]."SolutionTestQueue-".$model->id().$model->selected_version()."-".$Filename.".txt:BACK:fast:QSUB\"");
		#Eliminating queue file
		unlink($self->{"temp file directory"}->[0]."SolutionTestQueue-".$model->id().$model->selected_version()."-".$Filename.".txt");
		$ProcessorIndex = 0;
	}

	my $ErrorMatrixLines;
	my $Last = 1;
	if ($ProcessorIndex != -2) {
		#Reading in the original error matrix which has the headings for the original model simulation
		my $OriginalErrorData;
		if ($GapFill eq "GF" || $GapFill eq "GFSR") {
			$OriginalErrorData = LoadSingleColumnFile($model->directory().$model->id().$model->selected_version()."-OPEM".".txt","");
		} else {
			$OriginalErrorData = LoadSingleColumnFile($model->directory().$model->id().$model->selected_version()."-GGOPEM".".txt","");
		}
		my $HeadingHash;
		my @HeadingArray = split(/;/,$OriginalErrorData->[0]);
		my @OrigErrorArray = split(/;/,$OriginalErrorData->[1]);
		for (my $i=0; $i < @HeadingArray; $i++) {
			my @SubArray = split(/:/,$HeadingArray[$i]);
			$HeadingHash->{$SubArray[0].":".$SubArray[1].":".$SubArray[2]} = $i;
		}

		#Loading the gapfilling solution data
		my $GapFillResultTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($model->directory().$model->id().$model->selected_version()."-".$GapFill."S.txt",";","",0,undef);
		if (!defined($GapFillResultTable)) {
			print STDERR "FIGMODEL:TestSolutions: Could not load results table.";
			return 0;
		}

		#Scanning through the gap filling solutions
		print "Processor ".($ProcessorIndex+1)." of ".$NumProcessors." testing ".$GapFill." solutions!\n";
		my $GapFillingLines;
		my $CurrentIndex = 0;

		my $TempVersion = "V".$Filename."-".$ProcessorIndex;
		for (my $i=0; $i < $GapFillResultTable->size(); $i++) {
			if ($CurrentIndex == $ProcessorIndex) {
				print "Starting problem solving ".$i."\n";
				if (defined($GapFillResultTable->get_row($i)->{"Solution reactions"}->[0]) && $GapFillResultTable->get_row($i)->{"Solution reactions"}->[0] ne "none") {
					my $ErrorLine = $GapFillResultTable->get_row($i)->{"Experiment"}->[0].";".$i.";".$GapFillResultTable->get_row($i)->{"Solution cost"}->[0].";".$GapFillResultTable->get_row($i)->{"Solution reactions"}->[0];
					#Integrating solution into test model
					my $ReactionArray;
					my $DirectionArray;
					my @ReactionList = split(/,/,$GapFillResultTable->get_row($i)->{"Solution reactions"}->[0]);
					my %SolutionHash;
					for (my $k=0; $k < @ReactionList; $k++) {
						if ($ReactionList[$k] =~ m/(.+)(rxn\d\d\d\d\d)/) {
							my $Reaction = $2;
							my $Sign = $1;
							if (defined($SolutionHash{$Reaction})) {
								$SolutionHash{$Reaction} = "<=>";
							} elsif ($Sign eq "-") {
								$SolutionHash{$Reaction} = "<=";
							} elsif ($Sign eq "+") {
								$SolutionHash{$Reaction} = "=>";
							} else {
								$SolutionHash{$Reaction} = $Sign;
							}
						}
					}
					@ReactionList = keys(%SolutionHash);
					for (my $k=0; $k < @ReactionList; $k++) {
						push(@{$ReactionArray},$ReactionList[$k]);
						push(@{$DirectionArray},$SolutionHash{$ReactionList[$k]});
					}
					print "Integrating solution!\n";
					$self->IntegrateGrowMatchSolution($model->id().$model->selected_version(),$model->directory().$model->id().$TempVersion.".txt",$ReactionArray,$DirectionArray,"Gapfilling ".$GapFillResultTable->get_row($i)->{"Experiment"}->[0],1,1);
					my $testmodel = $self->get_model($model->id().$TempVersion);
					$testmodel->PrintModelLPFile();
					#Running the model against all available experimental data
					print "Running test model!\n";
					my ($FalsePostives,$FalseNegatives,$CorrectNegatives,$CorrectPositives,$Errorvector,$HeadingVector) = $testmodel->RunAllStudiesWithDataFast("All");

					@HeadingArray = split(/;/,$HeadingVector);
					my @ErrorArray = @OrigErrorArray;
					my @TempArray = split(/;/,$Errorvector);
					for (my $j=0; $j < @HeadingArray; $j++) {
						my @SubArray = split(/:/,$HeadingArray[$j]);
						$ErrorArray[$HeadingHash->{$SubArray[0].":".$SubArray[1].":".$SubArray[2]}] = $TempArray[$j];
					}
					$ErrorLine .= ";".$FalsePostives."/".$FalseNegatives.";".join(";",@ErrorArray);
				push(@{$ErrorMatrixLines},$ErrorLine);
				}
				print "Finishing problem solving ".$i."\n";
			}
			$CurrentIndex++;
			if ($CurrentIndex >= $NumProcessors) {
				$CurrentIndex = 0;
			}
		}

		print "Problem solving done! Checking if last...\n";

		#Clearing out the test model
		if (-e $model->directory().$model->id().$TempVersion.".txt") {
			unlink($model->directory().$model->id().$TempVersion.".txt");
			unlink($model->directory()."SimulationOutput".$model->id().$TempVersion.".txt");
		}

		#Printing the error array to file
		for (my $i=0; $i < $NumProcessors; $i++) {
			if ($i != $ProcessorIndex && !-e $model->directory().$model->id().$model->selected_version()."-".$GapFill."Error-".$i.".txt") {
				$Last = 0;
				last;
			}
		}
		print "Last checking done: ".$Last."\n";
	}

	if ($Last == 1 || $ProcessorIndex == -2) {
		print "combining all error files!\n";
		#Backing up the existing GFEM file
		if (-e $model->directory().$model->id().$model->selected_version()."-".$GapFill."EM.txt") {
			system("cp ".$model->directory().$model->id().$model->selected_version()."-".$GapFill."EM.txt ".$model->directory().$model->id().$model->selected_version()."-Old".$GapFill."EM.txt");
		}

		#Combining all the error matrices into a single file
		for (my $i=0; $i < $NumProcessors; $i++) {
			if (-e $model->directory().$model->id().$model->selected_version()."-".$GapFill."Error-".$i.".txt") {
				my $NewArray = LoadSingleColumnFile($model->directory().$model->id().$model->selected_version()."-".$GapFill."Error-".$i.".txt","");
				push(@{$ErrorMatrixLines},@{$NewArray});
				unlink($model->directory().$model->id().$model->selected_version()."-".$GapFill."Error-".$i.".txt");
			}
		}

		print "printing combined error file\n";
		#Printing the true error file
		PrintArrayToFile($model->directory().$model->id().$model->selected_version()."-".$GapFill."EM.txt",$ErrorMatrixLines);

		#Adding model to reconciliation queue
		if ($GapFill eq "GF") {
			system($self->{"scheduler executable"}->[0]." \"add:reconciliation?".$model->id().$model->selected_version()."?1:FRONT:cplex:QSUB\"");
		} elsif ($GapFill eq "GG") {
			system($self->{"scheduler executable"}->[0]." \"add:reconciliation?".$model->id().$model->selected_version()."?0:FRONT:cplex:QSUB\"");
		} elsif ($GapFill eq "GFSR") {
			system($self->{"scheduler executable"}->[0]." \"add:reconciliation?".$model->id().$model->selected_version()."?1?2:FRONT:fast:QSUB\"");
		} elsif ($GapFill eq "GGSR") {
			system($self->{"scheduler executable"}->[0]." \"add:reconciliation?".$model->id().$model->selected_version()."?0?2:FRONT:fast:QSUB\"");
		}

		print "updating growmatch table\n";
		my $GrowMatchTable = $self->database()->LockDBTable("GROWMATCH TABLE");
		my $Row = $GrowMatchTable->get_row_by_key($model->genome(),"ORGANISM",1);
		if ($GapFill eq "GF" || $GapFill eq "GG") {
			$Row->{$GapFill." TESTING TIMING"}->[0] .= time();
		}
		$GrowMatchTable->save();
		$self->database()->UnlockDBTable("GROWMATCH TABLE");
		print "done!\n";
	} else {
		print "printing results!\n";
		#Printing the processor specific error file
		PrintArrayToFile($model->directory().$model->id().$model->selected_version()."-".$GapFill."Error-".$ProcessorIndex.".txt",$ErrorMatrixLines);
	}

	return 1;
}

=head3 TestGapGenReconciledSolution
Definition:
	$model->TestGapGenReconciledSolution($ModelID,$Filename);
Description:
	This function resimulates all data adding each reaction in the gap gen solution one at a time to see where the model predictions go bad.
Example:
=cut

sub TestGapGenReconciledSolution {
	my ($self,$ModelID,$Stage) = @_;

	#Setting the filename with the solution data based on the input stage
	my $Filename = $Stage;
	if ($Stage eq "GG") {
		$Filename = $ModelID."-GG-FinalSolution.txt";
	} elsif ($Stage eq "GF") {
		$Filename = $ModelID."-GF-FinalSolution.txt";
	}

	#Getting model data
	my $modelObj = $self->get_model($ModelID);
	if (!defined($modelObj)) {
		print STDERR "FIGMODEL:TestGapGenReconciledSolution: Could not find model ".$ModelID.".\n";
		return;
	}
	my $Version = "";
	if (defined($modelObj->version())) {
		$Version = $modelObj->version();
	}
	$ModelID = $modelObj->id();

	#Loading solution file
	if (!-e $modelObj->directory().$Filename) {
		print STDERR "FIGMODEL:TestGapGenReconciledSolution: Could not find specified solution file ".$Filename." for ".$ModelID.".\n";
		return 0;
	}
	my $SolutionData = LoadMultipleColumnFile($modelObj->directory().$Filename,";");

	#Populating the KO list
	my $ReactionKO;
	my $MultiRunTable;
	if ($Stage eq "GG") {
		for (my $j=0; $j < @{$SolutionData}; $j++) {
			my $CurrentKO = "";
			for (my $i=0; $i < @{$SolutionData}; $i++) {
				if ($i != $j) {
					if (length($CurrentKO) > 0) {
						$CurrentKO .= ",";
					}
					if (defined($SolutionData->[$i]->[1]) && $SolutionData->[$i]->[1] eq "=>") {
						$CurrentKO .= "+".$SolutionData->[$i]->[0];
					} elsif (defined($SolutionData->[$i]->[1]) && $SolutionData->[$i]->[1] eq "<=") {
						$CurrentKO .= "-".$SolutionData->[$i]->[0];
					} else {
						$CurrentKO .= $SolutionData->[$i]->[0];
					}
				}
			}
			push(@{$ReactionKO},$CurrentKO);
		}
		#Simulating the knockouts using FBA
		$self->MultiRunAllStudiesWithData($ModelID.$Version,$ReactionKO,undef);
		#Loading the simulation results into a FIGMODELTable
		$MultiRunTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($modelObj->directory().$ModelID.$Version."-MultiSimulationResults.txt",";","\\|",0,undef);
	} elsif ($Stage eq "GF") {
		for (my $i=0; $i < @{$SolutionData}; $i++) {
			my $CurrentKO = "";
			if (defined($SolutionData->[$i]->[1]) && $SolutionData->[$i]->[1] eq "=>") {
				$CurrentKO = "+".$SolutionData->[$i]->[0];
			} elsif (defined($SolutionData->[$i]->[1]) && $SolutionData->[$i]->[1] eq "<=") {
				$CurrentKO = "-".$SolutionData->[$i]->[0];
			} else {
				my $ModelTable = $self->database()->GetDBModel($ModelID);
				if (defined($ModelTable)) {
					my $Row = $ModelTable->get_row_by_key($SolutionData->[$i]->[0],"LOAD");
					if (defined($Row)) {
						if ($Row->{"DIRECTIONALITY"}->[0] eq "=>") {
							$CurrentKO = "-".$SolutionData->[$i]->[0];
						} else {
							$CurrentKO = "+".$SolutionData->[$i]->[0];
						}
					} else {
						$CurrentKO = $SolutionData->[$i]->[0];
					}
				} else {
					$CurrentKO = $SolutionData->[$i]->[0];
				}
			}
			push(@{$ReactionKO},$CurrentKO);
		}
		#Simulating the knockouts using FBA
		$self->MultiRunAllStudiesWithData($ModelID."VGapFilled",$ReactionKO,undef);
		#Loading the simulation results into a FIGMODELTable
		$MultiRunTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($modelObj->directory().$ModelID."VGapFilled-MultiSimulationResults.txt",";","\\|",0,undef);
	} else {
		my $CurrentKO = "";
		for (my $i=0; $i < @{$SolutionData}; $i++) {
			if (length($CurrentKO) > 0) {
				$CurrentKO .= ",";
			}
			if (defined($SolutionData->[$i]->[1]) && $SolutionData->[$i]->[1] eq "=>") {
				$CurrentKO .= "+".$SolutionData->[$i]->[0];
			} elsif (defined($SolutionData->[$i]->[1]) && $SolutionData->[$i]->[1] eq "<=") {
				$CurrentKO .= "-".$SolutionData->[$i]->[0];
			} else {
				$CurrentKO .= $SolutionData->[$i]->[0];
			}
			push(@{$ReactionKO},$CurrentKO);
		}
		#Simulating the knockouts using FBA
		$self->MultiRunAllStudiesWithData($ModelID.$Version,$ReactionKO,undef);
		#Loading the simulation results into a FIGMODELTable
		$MultiRunTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($modelObj->directory().$ModelID.$Version."-MultiSimulationResults.txt",";","\\|",0,undef);
	}

	#Simulate the optimized/gapfilled version of the model to determine the reference model accuracy
	my ($FalsePostives,$FalseNegatives,$CorrectNegatives,$CorrectPositives,$Errorvector,$HeadingVector,$TempErrorVector,$TempHeadingVector);
	if ($Stage eq "GG") {
		($FalsePostives,$FalseNegatives,$CorrectNegatives,$CorrectPositives,$Errorvector,$HeadingVector) = $self->get_model($ModelID."VOptimized")->RunAllStudiesWithDataFast("All");
	} elsif ($Stage eq "GF") {
		($FalsePostives,$FalseNegatives,$CorrectNegatives,$CorrectPositives,$Errorvector,$HeadingVector) = $self->get_model($ModelID."VGapFilled")->RunAllStudiesWithDataFast("All");
	}
	push(@{$TempErrorVector},split(/;/,$Errorvector));
	push(@{$TempHeadingVector},split(/;/,$HeadingVector));

	#Determining the number of errors created/fixed by each reaction in the solution
	if (!defined($self->{$Stage." solution testing table"})) {
		$self->{$Stage." solution testing table"} = ModelSEED::FIGMODEL::FIGMODELTable->new(["Key","Reaction","Direction","Definition","Role","Subsystem","Subsystem class 2","Subsystem class 1","Models with reaction added during gap filling","False negative predictions fixed","False positive predictions generated"],$self->{"database message file directory"}->[0].$Stage."GrowmatchResults.txt",["Key"],";","|",undef);
	}

	#Adding the model column to the table
	$self->{$Stage." solution testing table"}->add_headings($ModelID);
	#Filling in the growmatch solution data for this model
	my $ZeroEffectReactions;
	my $ZeroEffectReactionResults;
	for (my $i=0; $i < @{$SolutionData}; $i++) {
		#Identifying the number of new errors generated
		my ($FixedErrors,$NewErrors) = $self->CompareErrorVectors($TempErrorVector,$TempHeadingVector,$MultiRunTable->get_row($i)->{"ERROR VECTOR"},$MultiRunTable->get_row($i)->{"HEADING VECTOR"});
		my $Row = $self->{$Stage." solution testing table"}->get_row_by_key($SolutionData->[$i]->[0].$SolutionData->[$i]->[1],"Key");
		if (!defined($Row)) {
			#Adding the row for thise reaction to the database
			$Row = {"Key" => [$SolutionData->[$i]->[0].$SolutionData->[$i]->[1]],"Direction" => [$SolutionData->[$i]->[1]],"Models with reaction added during gap filling" => [0],"False negative predictions fixed" => [0],"False positive predictions generated" => [0]};
			$self->{$Stage." solution testing table"}->add_row($Row);
			#Adding reaction data to hash
			$Row = $self->add_reaction_data_to_row($SolutionData->[$i]->[0],$Row,{"DATABASE" => "Reaction","SUBSYSTEM CLASS 1" => "Subsystem class 1","SUBSYSTEM CLASS 2" => "Subsystem class 2","SUBSYSTEM" => "Subsystem","ROLE" => "Role","DEFINITION" => "Definition"})
		}
		#Iterating the error count
		$Row->{"Models with reaction added during gap filling"}->[0]++;
		if (defined($FixedErrors)) {
			$Row->{"False negative predictions fixed"}->[0] += @{$FixedErrors};
		}
		if (defined($NewErrors)) {
			$Row->{"False positive predictions generated"}->[0] += @{$NewErrors};
		}
		if ($Row->{"False negative predictions fixed"}->[0] <= $Row->{"False positive predictions generated"}->[0]) {
			print $SolutionData->[$i]->[0].",".$SolutionData->[$i]->[1]."\n";
			push(@{$ZeroEffectReactions},$SolutionData->[$i]);
			$ZeroEffectReactionResults->{$SolutionData->[$i]} = $Row->{"False positive predictions generated"}->[0]-$Row->{"False negative predictions fixed"}->[0];
		}
		#Filling in the model column for this reaction
		$Row->{$ModelID}->[0] = "0";
		if (defined($FixedErrors)) {
			$Row->{$ModelID}->[0] = @{$FixedErrors}."(";
			for (my $j=0; $j < @{$FixedErrors}; $j++) {
				if ($j > 0) {
					$Row->{$ModelID}->[0] .= ",";
				}
				my @TempArray = split(/:/,$FixedErrors->[$j]);
				if ($TempArray[0] eq "Gene KO") {
					$Row->{$ModelID}->[0] .= $TempArray[2];
				} else {
					$Row->{$ModelID}->[0] .= $TempArray[1];
				}
			}
			$Row->{$ModelID}->[0] .= ")";
		}
		$Row->{$ModelID}->[0] .= "|";
		if (defined($NewErrors)) {
			$Row->{$ModelID}->[0] .= @{$NewErrors}."(";
			for (my $j=0; $j < @{$NewErrors}; $j++) {
				if ($j > 0) {
					$Row->{$ModelID}->[0] .= ",";
				}
				my @TempArray = split(/:/,$NewErrors->[$j]);
				if ($TempArray[0] eq "Gene KO") {
					$Row->{$ModelID}->[0] .= $TempArray[2];
				} else {
					$Row->{$ModelID}->[0] .= $TempArray[1];
				}
			}
			$Row->{$ModelID}->[0] .= ")";
		} else {
			$Row->{$ModelID}->[0] .= "0";
		}
	}

	#Trying to remove all zero error reactions
	if (defined($ZeroEffectReactions) && @{$ZeroEffectReactions}) {
		@{$ZeroEffectReactions} = sort { $ZeroEffectReactionResults->{$b} <=> $ZeroEffectReactionResults->{$a} } @{$ZeroEffectReactions};
		#$self->IdentifyReactionsToRemove($ZeroEffectReactions,$ModelID,$Stage);
	}
}

=head3 RemoveNoEffectReactions
Definition:
	$model->RemoveNoEffectReactions(string::model ID);
Description:
Example:
=cut

sub RemoveNoEffectReactions {
	my ($self,$ModelID,$Stage) = @_;

	#Getting reaction directory
	my $modelObj = $self->get_model($ModelID);
	if (!defined($modelObj)) {
		print STDERR "FIGMODEL:RemoveNoEffectReactions: Could not find model ".$ModelID.".\n";
		return;
	}

	#Checking if the no effect file exists
	if (!-e $modelObj->directory()."NoEffectReactions-".$Stage."-".$ModelID."VOptimized.txt") {
		return;
	}

	#Loading no effect reaction list
	my $ReactionList = LoadSingleColumnFile($modelObj->directory()."NoEffectReactions-".$Stage."-".$ModelID."VOptimized.txt","");
	my $Hash;
	for (my $i=0; $i < @{$ReactionList}; $i++) {
		if ($ReactionList->[$i] =~ m/\+/) {
			$Hash->{substr($ReactionList->[$i],1)} = "=>";
		} elsif ($ReactionList->[$i] =~ m/\-/) {
			$Hash->{substr($ReactionList->[$i],1)} = "<=";
		} else {
			$Hash->{$ReactionList->[$i]} = "<=>";
		}
	}

	#Loading original reaction list
	my $OriginalReactionList;
	if ($Stage eq "GF") {
		$OriginalReactionList = LoadMultipleColumnFile($modelObj->directory().$ModelID."-GF-FinalSolution.txt",";");
	} else {
		if (-e $modelObj->directory().$ModelID."-GG-FinalSolution.txt") {
			$OriginalReactionList = LoadMultipleColumnFile($modelObj->directory().$ModelID."-GG-FinalSolution.txt",";");
		} elsif (-e $modelObj->directory().$ModelID."VGapFilled-GG-FinalSolution.txt") {
			$OriginalReactionList = LoadMultipleColumnFile($modelObj->directory().$ModelID."VGapFilled-GG-FinalSolution.txt",";");
		}
	}

	#Removing no effect reactions from the original reaction list
	my $NewReactionList;
	my $ReactionArray;
	my $DirectionArray;
	for (my $i=0; $i < @{$OriginalReactionList}; $i++) {
		if (!defined($Hash->{$OriginalReactionList->[$i]->[0]})) {
			push(@{$ReactionArray},$OriginalReactionList->[$i]->[0]);
			push(@{$DirectionArray},$OriginalReactionList->[$i]->[1]);
			push(@{$NewReactionList},$OriginalReactionList->[$i]->[0].";".$OriginalReactionList->[$i]->[1]);
		} elsif ($Hash->{$OriginalReactionList->[$i]->[0]} ne $OriginalReactionList->[$i]->[1] && $OriginalReactionList->[$i]->[1] ne "<=>") {
			push(@{$ReactionArray},$OriginalReactionList->[$i]->[0]);
			push(@{$DirectionArray},$OriginalReactionList->[$i]->[1]);
			push(@{$NewReactionList},$OriginalReactionList->[$i]->[0].";".$OriginalReactionList->[$i]->[1]);
		} elsif ($Hash->{$OriginalReactionList->[$i]->[0]} ne $OriginalReactionList->[$i]->[1]) {
			for (my $j=0; $j < @{$OriginalReactionList}; $j++) {
				if ($j != $i && $OriginalReactionList->[$j]->[0] eq $OriginalReactionList->[$i]->[0]) {
					if ($Hash->{$OriginalReactionList->[$i]->[0]} eq $OriginalReactionList->[$j]->[1]) {
						push(@{$ReactionArray},$OriginalReactionList->[$i]->[0]);
						push(@{$DirectionArray},$OriginalReactionList->[$i]->[1]);
						push(@{$NewReactionList},$OriginalReactionList->[$i]->[0].";".$OriginalReactionList->[$i]->[1]);
						last;
					}
				}
			}
		}
	}

	if ($Stage eq "GF") {
		#Printing new reaction list
		PrintArrayToFile($modelObj->directory().$ModelID."-GF-NewFinalSolution.txt",$NewReactionList);

		#Integrating new solution
		$self->IntegrateGrowMatchSolution($ModelID,$modelObj->directory().$ModelID."VGapFilledNew.txt",$ReactionArray,$DirectionArray,"GROWMATCH",1,1);
		my $model = $self->get_model($ModelID."VGapFilledNew");
		$model->PrintModelLPFile();

		#Rerunning the simulation
		my ($FalsePostives,$FalseNegatives,$CorrectNegatives,$CorrectPositives,$Errorvector,$HeadingVector) = $self->get_model($ModelID."VGapFilledNew")->RunAllStudiesWithDataFast("All");
		my ($OldFalsePostives,$OldFalseNegatives,$OldCorrectNegatives,$OldCorrectPositives,$OldErrorvector,$OldHeadingVector) = $self->get_model($ModelID."VGapFilled")->RunAllStudiesWithDataFast("All");

		#Checking that the new model file has the same accuracy as the old file
		if (($FalsePostives+$FalseNegatives) <= ($OldFalsePostives+$OldFalseNegatives)) {
			print "GF Accepted!\n";
			system("rm ".$modelObj->directory().$ModelID."-GF-OldFinalSolution.txt");
			system("rm ".$modelObj->directory().$ModelID."VGapFilledOld.txt");
			system("rm ".$modelObj->directory()."SimulationOutput".$ModelID."VGapFilledOld.txt");
			system("mv ".$modelObj->directory().$ModelID."-GF-FinalSolution.txt ".$modelObj->directory().$ModelID."-GF-OldFinalSolution.txt");
			system("mv ".$modelObj->directory().$ModelID."-GF-NewFinalSolution.txt ".$modelObj->directory().$ModelID."-GF-FinalSolution.txt");
			system("mv ".$modelObj->directory().$ModelID."VGapFilled.txt ".$modelObj->directory().$ModelID."VGapFilledOld.txt");
			system("mv ".$modelObj->directory().$ModelID."VGapFilledNew.txt ".$modelObj->directory().$ModelID."VGapFilled.txt");
			system("mv ".$modelObj->directory()."SimulationOutput".$ModelID."VGapFilled.txt ".$modelObj->directory()."SimulationOutput".$ModelID."VGapFilledOld.txt");
			system("mv ".$modelObj->directory()."SimulationOutput".$ModelID."VGapFilledNew.txt ".$modelObj->directory()."SimulationOutput".$ModelID."VGapFilled.txt");
			if (-e $modelObj->directory().$ModelID."VGapFilled-GG-FinalSolution.txt") {
				#Integrating new solution
				$ReactionArray = ();
				$DirectionArray = ();
				$OriginalReactionList = LoadMultipleColumnFile($modelObj->directory().$ModelID."VGapFilled-GG-FinalSolution.txt",";");
				for (my $i=0; $i < @{$OriginalReactionList}; $i++) {
					push(@{$ReactionArray},$OriginalReactionList->[$i]->[0]);
					push(@{$DirectionArray},$OriginalReactionList->[$i]->[1]);
				}
				$self->IntegrateGrowMatchSolution($ModelID."VGapFilled",$modelObj->directory().$ModelID."VOptimizedNew.txt",$ReactionArray,$DirectionArray,"GROWMATCH",1,1);
				my $model = $self->get_model($ModelID."VOptimizedNew");
				$model->PrintModelLPFile();

				#Rerunning the simulation
				($FalsePostives,$FalseNegatives,$CorrectNegatives,$CorrectPositives,$Errorvector,$HeadingVector) = $self->get_model($ModelID."VOptimizedNew")->RunAllStudiesWithDataFast("All");
				($OldFalsePostives,$OldFalseNegatives,$OldCorrectNegatives,$OldCorrectPositives,$OldErrorvector,$OldHeadingVector) = $self->get_model($ModelID."VOptimized")->RunAllStudiesWithDataFast("All");

				#Checking that the new model file has the same accuracy as the old file
				if (($FalsePostives+$FalseNegatives) <= ($OldFalsePostives+$OldFalseNegatives)) {
					print "GF Opt Accepted!\n";
					system("rm ".$modelObj->directory()."SimulationOutput".$ModelID."VOptimizedOld.txt");
					system("rm ".$modelObj->directory().$ModelID."VOptimizedOld.txt");
					system("mv ".$modelObj->directory()."SimulationOutput".$ModelID."VOptimized.txt ".$modelObj->directory()."SimulationOutput".$ModelID."VOptimizedOld.txt");
					system("mv ".$modelObj->directory().$ModelID."VOptimized.txt ".$modelObj->directory().$ModelID."VOptimizedOld.txt");
					system("mv ".$modelObj->directory()."SimulationOutput".$ModelID."VOptimizedNew.txt ".$modelObj->directory()."SimulationOutput".$ModelID."VOptimized.txt");
					system("mv ".$modelObj->directory().$ModelID."VOptimizedNew.txt ".$modelObj->directory().$ModelID."VOptimized.txt");
				} else {
					print STDERR "FIGMODEL:RemoveNoEffectReactions:Removal of no effect reactions failed for optimized ".$ModelID."!\n";
				}
			}
		} else {
			print STDERR "FIGMODEL:RemoveNoEffectReactions:Removal of no effect reactions failed for gapfilled ".$ModelID."!\n";
		}
	} else {
		my $BaseModel = $ModelID;
		if (-e $modelObj->directory().$ModelID."VGapFilled-GG-FinalSolution.txt") {
			$BaseModel = $ModelID."VGapFilled";
		}
		if (-e $modelObj->directory().$BaseModel."-GG-FinalSolution.txt") {
			#Integrating new solution
			$self->IntegrateGrowMatchSolution($BaseModel,$modelObj->directory().$ModelID."VOptimizedNew.txt",$ReactionArray,$DirectionArray,"GROWMATCH",1,1);
			my $model = $self->get_model($ModelID."VOptimizedNew");
			$model->PrintModelLPFile();

			#Rerunning the simulation
			my ($FalsePostives,$FalseNegatives,$CorrectNegatives,$CorrectPositives,$Errorvector,$HeadingVector) = $self->get_model($ModelID."VOptimizedNew")->RunAllStudiesWithDataFast("All");
			my ($OldFalsePostives,$OldFalseNegatives,$OldCorrectNegatives,$OldCorrectPositives,$OldErrorvector,$OldHeadingVector) = $self->get_model($ModelID."VOptimized")->RunAllStudiesWithDataFast("All");

			#Checking that the new model file has the same accuracy as the old file
			if (($FalsePostives+$FalseNegatives) <= ($OldFalsePostives+$OldFalseNegatives)) {
				print "GG Accepted!\n";
				system("rm ".$modelObj->directory()."SimulationOutput".$ModelID."VOptimizedOld.txt");
				system("rm ".$modelObj->directory().$ModelID."VOptimizedOld.txt");
				system("mv ".$modelObj->directory()."SimulationOutput".$ModelID."VOptimized.txt ".$modelObj->directory()."SimulationOutput".$ModelID."VOptimizedOld.txt");
				system("mv ".$modelObj->directory().$ModelID."VOptimized.txt ".$modelObj->directory().$ModelID."VOptimizedOld.txt");
				system("mv ".$modelObj->directory()."SimulationOutput".$ModelID."VOptimizedNew.txt ".$modelObj->directory()."SimulationOutput".$ModelID."VOptimized.txt");
				system("mv ".$modelObj->directory().$ModelID."VOptimizedNew.txt ".$modelObj->directory().$ModelID."VOptimized.txt");
			} else {
				print STDERR "FIGMODEL:RemoveNoEffectReactions:Removal of no effect reactions failed for optimized ".$ModelID."!\n";
			}
		}
	}
}

=head3 IdentifyReactionsToRemove
Definition:
	$model->IdentifyReactionsToRemove(2D array ref::list of reactions and direction,string::model ID,string::stage);
Description:
Example:
=cut

sub IdentifyReactionsToRemove {
	my ($self,$ReactionList,$ModelID,$Stage) = @_;

	#Parsing reactions and directions to get reactions formatted for KO
	my $TrueList;
	for (my $i=0; $i < @{$ReactionList}; $i++) {
		if (defined($ReactionList->[$i]->[1]) && $ReactionList->[$i]->[1] eq "=>") {
			push(@{$TrueList},"+".$ReactionList->[$i]->[0]);
		} elsif (defined($ReactionList->[$i]->[1]) && $ReactionList->[$i]->[1] eq "<=") {
			push(@{$TrueList},"-".$ReactionList->[$i]->[0]);
		} else {
			my $ModelTable = $self->database()->GetDBModel($ModelID);
			if (defined($ModelTable)) {
				my $Row = $ModelTable->get_row_by_key($ReactionList->[$i]->[0],"LOAD");
				if (defined($Row)) {
					if ($Row->{"DIRECTIONALITY"}->[0] eq "=>") {
						push(@{$TrueList},"-".$ReactionList->[$i]->[0]);
					} else {
						push(@{$TrueList},"+".$ReactionList->[$i]->[0]);
					}
				} else {
					push(@{$TrueList},$ReactionList->[$i]->[0]);
				}
			} else {
				push(@{$TrueList},$ReactionList->[$i]->[0]);
			}
		}
	}

	#Simulating the unmodified model
	my $modelObj = $self->get_model($ModelID);
	my $Directory = $modelObj->directory();
	my $BaseModel = $ModelID."VGapFilled";
	if (!-e $Directory.$BaseModel.".txt") {
		$BaseModel = $ModelID;
	}
	my $Version = "VOptimized";
	if (!-e $Directory.$ModelID.$Version.".txt") {
		$Version = "VGapFilled";
	}
	if (!-e $Directory.$ModelID.$Version.".txt") {
		return;
	}
	my ($FalsePostives,$FalseNegatives,$CorrectNegatives,$CorrectPositives,$Errorvector,$HeadingVector) = $self->get_model($ModelID.$Version)->RunAllStudiesWithDataFast("All");
	print $FalsePostives.":".$FalseNegatives."\n";

	#Loading original reaction list
	my $OtherData;
	if ($Stage eq "GG") {
		my $OriginalReactionList = LoadMultipleColumnFile($modelObj->directory().$ModelID."VGapFilled-GG-FinalSolution.txt",";");
		for (my $i=0; $i < @{$OriginalReactionList}; $i++) {
			print $OriginalReactionList->[$i]->[0]."\t".$OriginalReactionList->[$i]->[1]."\n";
			$OtherData->[$i]->[0] = $OriginalReactionList->[$i]->[0];
			$OtherData->[$i]->[1] = $OriginalReactionList->[$i]->[1];
			if ($OriginalReactionList->[$i]->[1] eq "=>") {
				$OtherData->[$i]->[2] = "+".$OriginalReactionList->[$i]->[0];
			} elsif ($OriginalReactionList->[$i]->[1] eq "<=") {
				$OtherData->[$i]->[2] = "-".$OriginalReactionList->[$i]->[0];
			} else {
				$OtherData->[$i]->[2] = $OriginalReactionList->[$i]->[0];
			}
		}
	}

	#Progressively simulating knockout of reactions to determine impact on predictions
	my $KOReactions = "";
	my $FinalList;
	for (my $i=0; $i < @{$TrueList}; $i++) {
		my $NewFP;
		my $NewFN;
		my $NewKO;
		if ($Stage eq "GF") {
			$NewKO = $KOReactions;
			if (length($NewKO) > 0) {
				$NewKO .= ",";
			}
			$NewKO .= $TrueList->[$i];
			$self->MultiRunAllStudiesWithData($ModelID.$Version,[$NewKO],undef);
			#Loading the simulation results into a FIGMODELTable
			my $MultiRunTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($Directory.$ModelID.$Version."-MultiSimulationResults.txt",";","\\|",0,undef);
			$NewFP = $MultiRunTable->get_row(0)->{"FALSE POSITIVES"}->[0];
			$NewFN = $MultiRunTable->get_row(0)->{"FALSE NEGATIVES"}->[0];
		} else {
			my $ReactionArray;
			my $DirectionArray;
			for (my $j=0; $j < @{$OtherData}; $j++) {
				my $Found = 0;
				if (defined($FinalList)) {
					for (my $k=0; $k < @{$FinalList}; $k++) {
						if ($FinalList->[$k] eq $OtherData->[$j]->[2]) {
							$Found = 1;
							last;
						}
					}
				}
				if ($Found == 0) {
					push(@{$ReactionArray},$OtherData->[$j]->[0]);
					push(@{$DirectionArray},$OtherData->[$j]->[1]);
				}
			}
			#Integrating new solution
			$self->IntegrateGrowMatchSolution($BaseModel,$modelObj->directory().$ModelID."VTest.txt",$ReactionArray,$DirectionArray,"GROWMATCH",1,1);
			my $model = $self->get_model($ModelID."VTest");
			$model->PrintModelLPFile();
			#Simulating the test model to determine if the combined deletion had no negative effect
			($NewFP,$NewFN,my $NewCN,my $NewCP,my $NewEV,my $NewHV) = $self->get_model($ModelID."VTest")->RunAllStudiesWithDataFast("All");
		}
		if (($NewFP+$NewFN) <= ($FalsePostives+$FalseNegatives)) {
			$KOReactions = $NewKO;
			push(@{$FinalList},$TrueList->[$i]);
			print "Accepted:".$NewFP.":".$NewFN.":".$TrueList->[$i]."\n";
			$FalsePostives = $NewFP;
			$FalseNegatives = $NewFN;
		} else {
			print "Rejected:".$TrueList->[$i]."\n";
		}
	}

	#Printing result
	PrintArrayToFile($Directory."NoEffectReactions-".$Stage."-".$ModelID.$Version.".txt",$FinalList);
	#$self->RemoveNoEffectReactions($ModelID,$Stage);
}

=head3 add_reaction_data_to_row
Definition:
	(figmodeltable row::reaction row) = $model->add_reaction_data_to_row(,figmodeltable row::reaction row,string hash ref::headings);
Description:
Example:
=cut

sub add_reaction_data_to_row {
	my ($self,$ID,$Row,$HeadingsHash) = @_;

	my @Headings = keys(%{$HeadingsHash});
	for (my $i=0; $i < @Headings; $i++) {
		if ($Headings[$i] eq "DATABASE") {
			$Row->{$HeadingsHash->{$Headings[$i]}}->[0] = $ID;
		} elsif ($Headings[$i] eq "SUBSYSTEM CLASS 1") {
			my $SubsystemListRef = $self->subsystems_of_reaction($ID);
			if (defined($SubsystemListRef)) {
				for (my $k=0; $k < @{$SubsystemListRef}; $k++) {
					my $SubsystemClasses = $self->class_of_subsystem($SubsystemListRef->[$k]);
					if (defined($SubsystemClasses)) {
						$SubsystemClasses->[0] =~ s/;/,/;
						push(@{$Row->{$HeadingsHash->{$Headings[$i]}}},$SubsystemClasses->[0]);
					}
				}
			}
			if (!defined($Row->{$HeadingsHash->{$Headings[$i]}})) {
				$Row->{$HeadingsHash->{$Headings[$i]}}->[0] = "NONE"
			}
		} elsif ($Headings[$i] eq "SUBSYSTEM CLASS 2") {
			my $SubsystemListRef = $self->subsystems_of_reaction($ID);
			if (defined($SubsystemListRef)) {
				for (my $k=0; $k < @{$SubsystemListRef}; $k++) {
					my $SubsystemClasses = $self->class_of_subsystem($SubsystemListRef->[$k]);
					if (defined($SubsystemClasses)) {
						$SubsystemClasses->[1] =~ s/;/,/;
						push(@{$Row->{$HeadingsHash->{$Headings[$i]}}},$SubsystemClasses->[1]);
					}
				}
			}
			if (!defined($Row->{$HeadingsHash->{$Headings[$i]}})) {
				$Row->{$HeadingsHash->{$Headings[$i]}}->[0] = "NONE"
			}
		} elsif ($Headings[$i] eq "ROLE") {
			my $RoleData = $self->roles_of_reaction($ID);
			if (defined($RoleData)) {
				$Row->{$HeadingsHash->{$Headings[$i]}} = $RoleData;
			}
			if (!defined($Row->{$HeadingsHash->{$Headings[$i]}})) {
				$Row->{$HeadingsHash->{$Headings[$i]}}->[0] = "NONE"
			}
		} elsif ($Headings[$i] eq "SUBSYSTEM") {
			my $SubsystemListRef = $self->subsystems_of_reaction($ID);
			if (defined($SubsystemListRef)) {
				$Row->{$HeadingsHash->{$Headings[$i]}} = $SubsystemListRef;
			}
			if (!defined($Row->{$HeadingsHash->{$Headings[$i]}})) {
				$Row->{$HeadingsHash->{$Headings[$i]}}->[0] = "NONE"
			}
		} elsif ($Headings[$i] eq "DEFINITION") {
			my $ReactionObject = $self->LoadObject($ID);
			if (defined($ReactionObject) && defined($ReactionObject->{"DEFINITION"}->[0])) {
				$Row->{$HeadingsHash->{$Headings[$i]}}->[0] = $ReactionObject->{"DEFINITION"}->[0];
			}
		}
	}

	return $Row;
}

=head3 CompareErrorVectors
Definition:
	(string array ref::new errors,string array ref::fixed errors) = $model->CompareErrorVectors(string array ref::error vector one,string array ref::heading vector one,string array ref::error vector two,string array ref::heading vector two);
Description:
Example:
=cut

sub CompareErrorVectors {
	my ($self,$ErrorOne,$HeadingOne,$ErrorTwo,$HeadingTwo) = @_;

	my ($ErrorOneCorrectTwo,$CorrectOneErrorTwo);
	my $ErrorHashOne;
	my $ErrorHashTwo;
	for (my $i=0; $i < @{$ErrorOne}; $i++) {
		$ErrorHashOne->{$HeadingOne->[$i]} = $ErrorOne->[$i];
	}
	for (my $i=0; $i < @{$ErrorTwo}; $i++) {
		$ErrorHashTwo->{$HeadingTwo->[$i]} = $ErrorTwo->[$i];
	}
	for (my $i=0; $i < @{$ErrorOne}; $i++) {
		if (defined($ErrorHashTwo->{$HeadingOne->[$i]})) {
			if ($ErrorOne->[$i] > 1) {
				if ($ErrorHashTwo->{$HeadingOne->[$i]} <= 1) {
					push(@{$ErrorOneCorrectTwo},$HeadingOne->[$i]);
				}
			} else {
				if ($ErrorHashTwo->{$HeadingOne->[$i]} > 1) {
					push(@{$CorrectOneErrorTwo},$HeadingOne->[$i]);
				}
			}
		} elsif ($ErrorOne->[$i] > 1) {
			push(@{$ErrorOneCorrectTwo},$HeadingOne->[$i]);
		}
	}
	for (my $i=0; $i < @{$ErrorTwo}; $i++) {
		if (!defined($ErrorHashOne->{$HeadingTwo->[$i]})) {
			if ($ErrorTwo->[$i] > 1) {
				push(@{$CorrectOneErrorTwo},$HeadingTwo->[$i]);
			}
		}
	}
	return ($CorrectOneErrorTwo,$ErrorOneCorrectTwo);
}

=head3 TestDatabaseBiomassProduction
Definition:
	$model->TestDatabaseBiomassProduction($Biomass,$Media,$BalancedReactionsOnly);
Description:
Example:
=cut

sub TestDatabaseBiomassProduction {
	my ($self,$Biomass,$Media,$BalancedReactionsOnly) = @_;

	my $BalanceParameter = 1;
	if (defined($BalancedReactionsOnly) && $BalancedReactionsOnly == 0) {
		$BalanceParameter = 0;
	}

	my $UniqueFilename = $self->filename();
	if (defined($Media) && $Media ne "Complete" && -e $self->{"Media directory"}->[0].$Media.".txt") {
		#Loading media, changing bounds, saving media as a test media
		my $MediaTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->{"Media directory"}->[0].$Media.".txt",";","",0,["VarName"]);
		for (my $i=0; $i < $MediaTable->size(); $i++) {
			if ($MediaTable->get_row($i)->{"Min"}->[0] < 0) {
				$MediaTable->get_row($i)->{"Min"}->[0] = -10000;
			}
			if ($MediaTable->get_row($i)->{"Max"}->[0] > 0) {
				$MediaTable->get_row($i)->{"Max"}->[0] = 10000;
			}
		}
		$MediaTable->save($self->{"Media directory"}->[0].$UniqueFilename."TestMedia.txt");
		system($self->GenerateMFAToolkitCommandLineCall($UniqueFilename,"Complete",$UniqueFilename."TestMedia",["DatabaseMFA"],{"Default max drain flux" => 0,"Complete model biomass reaction" => $Biomass,"Balanced reactions in gap filling only" => $BalanceParameter},"DatabaseBiomassTest-".$Biomass."-".$Media.".log",undef));
		unlink($self->{"Media directory"}->[0].$UniqueFilename."TestMedia.txt");
	} else {
		system($self->GenerateMFAToolkitCommandLineCall($UniqueFilename,"Complete","NONE",["DatabaseMFA"],{"Complete model biomass reaction" => $Biomass,"Balanced reactions in gap filling only" => $BalanceParameter},"DatabaseBiomassTest-".$Biomass."-".$Media.".log",undef));
	}
	#If the system is not configured to preserve all logfiles, then the output printout from the mfatoolkit is deleted
	if ($self->{"preserve all log files"}->[0] eq "no") {
		unlink($self->{"database message file directory"}->[0]."DatabaseBiomassTest-".$Biomass."-".$Media.".log");
	}

	#Reading the problem report and parsing out the zero production metabolites
	my $ProblemReport = $self->LoadProblemReport($UniqueFilename);
	return $ProblemReport;
}

=head3 GapGenerationAlgorithm

Definition:
	$model->GapGenerationAlgorithm($ModelName,$NumberOfProcessors,$ProcessorIndex,$Filename);

Description:

Example:
	$model->GapGenerationAlgorithm("Seed100226.1");

=cut
sub GapGenerationAlgorithm {
	my ($self,$ModelID,$ProcessIndex,$Media,$KOList,$NoKOList,$NumProcesses) = @_;
	my $model = $self->get_model($ModelID);
	#Getting unique filename
	my $Filename = $self->filename();
	#This is the code for the scheduler
	if (!defined($ProcessIndex) || $ProcessIndex == -1) {
		#Now we check that the reaction essentiality file exist
		if (!-e $model->directory().$model->id().$model->selected_version()."-ReactionKOResult.txt") {
			print STDERR "FIGMODEL:GapGenerationAlgorithm: Reaction essentiality file not found for ".$model->id().$model->selected_version().".\n";
			return 0;
		}

		#Determining the performance of the wildtype model
		my ($FalsePostives,$FalseNegatives,$CorrectNegatives,$CorrectPositives,$Errorvector,$HeadingVector) = $model->RunAllStudiesWithDataFast("All");
		PrintArrayToFile($model->directory().$model->id().$model->selected_version()."-GGOPEM".".txt",[$HeadingVector,$Errorvector]);

		#Now we read in the reaction essentiality file
		my $EssentialityTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($model->directory().$model->id().$model->selected_version()."-ReactionKOResult.txt",";","",0,["REACTION"]);
		#Identifying which reactions should not be knocked out by the gap generation
		my $ConservedList;
		for (my $i=0; $i < $EssentialityTable->size(); $i++) {
			if (($EssentialityTable->get_row($i)->{"FALSE NEGATIVES"}->[0] - $FalseNegatives) > 5) {
				push(@{$ConservedList},$EssentialityTable->get_row($i)->{"REACTION"}->[0]);
			}
		}
		$NoKOList = join(",",@{$ConservedList});

		#Now we use the simulation output to make the gap generation run data
		my @Errors = split(/;/,$Errorvector);
		my @Headings = split(/;/,$HeadingVector);
		my $GapGenerationRunData;
		my $Count = 0;
		for (my $i=0; $i < @Errors; $i++) {
			if ($Errors[$i] == 2) {
				my @HeadingDataArray = split(/:/,$Headings[$i]);
				$GapGenerationRunData->[$Count]->[2] = $HeadingDataArray[2];
				$GapGenerationRunData->[$Count]->[0] = $HeadingDataArray[3];
				$GapGenerationRunData->[$Count]->[1] = $HeadingDataArray[1];
				$GapGenerationRunData->[$Count]->[0] =~ s/;/,/g;
				$Count++;
			}
		}

		#Checking if there are no false positives
		if (!defined($GapGenerationRunData) || @{$GapGenerationRunData} == 0) {
			print "NO FALSE POSITIVE PREDICTIONS FOR MODEL\n";
			return 1;
		}

		#Scheduling all the gap generation optimization jobs
		my $ProcessList;
		if (-e $model->directory().$model->id().$model->selected_version()."-GG-0-S.txt") {
			unlink($model->directory().$model->id().$model->selected_version()."-GG-0-EM.txt");
			unlink($model->directory().$model->id().$model->selected_version()."-GG-0-S.txt");
		}
		for (my $i=1; $i < @{$GapGenerationRunData}; $i++) {
			#Deleting any old residual problem reports
			if (-e $model->directory().$model->id().$model->selected_version()."-GG-".$i."-S.txt") {
				unlink($model->directory().$model->id().$model->selected_version()."-GG-".$i."-S.txt");
				unlink($model->directory().$model->id().$model->selected_version()."-GG-".$i."-EM.txt");
			}
			push(@{$ProcessList},"rungapgeneration?".$model->id().$model->selected_version()."?".$i."?".$GapGenerationRunData->[$i]->[1]."?".$GapGenerationRunData->[$i]->[0]."?".$NoKOList."?".@{$GapGenerationRunData});
		}
		PrintArrayToFile($self->{"temp file directory"}->[0]."GapGenQueue-".$model->id().$model->selected_version()."-".$Filename.".txt",$ProcessList);
		system($self->{"scheduler executable"}->[0]." \"add:".$self->{"temp file directory"}->[0]."GapGenQueue-".$model->id().$model->selected_version()."-".$Filename.".txt:BACK:test:QSUB\"");
		unlink($self->{"temp file directory"}->[0]."GapGenQueue-".$model->id().$model->selected_version()."-".$Filename.".txt");

		#Converting this processor into process zero
		$ProcessIndex = 0;
		$Media = $GapGenerationRunData->[0]->[1];
		$KOList = $GapGenerationRunData->[0]->[0];
		$NumProcesses = @{$GapGenerationRunData};
	}

	#This code handles the running and testing of gap generation solutions
	if ($ProcessIndex != -2) {
		my $GapGenResults = $model->datagapgen($Media,$KOList,$NoKOList,"-".$ProcessIndex."-S");
		$GapGenResults->save();
		system($self->{"scheduler executable"}->[0]." \"add:testsolutions?".$model->id().$model->selected_version()."?0?GG-".$ProcessIndex."-?1:BACK:fast:QSUB\"");
		#Checking if this is the last process to finish
		my $Last = 1;
		for (my $i=0; $i < $NumProcesses; $i++) {
			if (!-e $model->directory().$model->id().$model->selected_version()."-GG-".$i."-S.txt") {
				$Last = 0;
			}
		}
		#If this is the last job to finish, we activate the cleanup gap generation
		if ($Last == 1) {
			system($self->{"scheduler executable"}->[0]." \"add:rungapgeneration?".$model->id().$model->selected_version()."?-2:BACK:fast:QSUB\"");
		}
		return 1;
	}

	#This code combines all of the output from the job threads into a single file and a single error matrix
	my @FileList = glob($model->directory().$model->id().$model->selected_version()."-GG-*");
	my $TestList;
	my $CombinedFile = ["Experiment;Solution index;Solution cost;Solution reactions"];
	foreach my $Filename (@FileList) {
		if ($Filename =~ m/(.+-)S\.txt$/) {
			push(@{$TestList},$1."EM.txt");
			my $CurrentFile = LoadSingleColumnFile($Filename,"");
			#unlink($Filename);
			shift(@{$CurrentFile});
			push(@{$CombinedFile},@{$CurrentFile});
		}
	}
	PrintArrayToFile($model->directory().$model->id().$model->selected_version()."-GGS.txt",$CombinedFile);
	#Waiting for all solution testing to complete
	my $Done = 0;
	while ($Done == 0) {
		$Done = 1;
		foreach my $Filename (@{$TestList}) {
			if (!-e $Filename) {
				$Done = 0;
				last;
			}
		}
		if ($Done == 0) {
			sleep(180);
		}
	}
	#Combining the error file
	$CombinedFile = undef;
	foreach my $Filename (@{$TestList}) {
		my $CurrentFile = LoadSingleColumnFile($Filename,"");
		push(@{$CombinedFile},@{$CurrentFile});
	}
	PrintArrayToFile($model->directory().$model->id().$model->selected_version()."-GGEM.txt",$CombinedFile);
	#Adding model to the reconciliation queue
	system($self->{"scheduler executable"}->[0]." \"add:reconciliation?".$model->id().$model->selected_version()."?0:FRONT:cplex:QSUB\"");

	return 1;
}

=head3 SwiftGapGeneationAlgorithm
Definition:
	$model->SwiftGapGeneationAlgorithm($ModelName,$Filename);
Description:
Example:
	$model->SwiftGapGeneationAlgorithm("Seed100226.1");
=cut

sub SwiftGapGeneationAlgorithm {
	my ($self,$ModelID,$Filename,$Stage) = @_;

	#Checking that the input directory exists
	if (defined(!$Filename)) {
		$Filename = "CurrentSwift/";
	}
	if (!-d "/home/chenry/SwiftGapGen/".$Filename) {
		system("mkdir /home/chenry/SwiftGapGen/".$Filename);
	}

	#First checking that the model exists and finding model directory and version
	my $model = $self->get_model($ModelID);
	if (!defined($model)) {
		print STDERR "FIGMODEL:GapGenerationAlgorithm: Could not find model ".$ModelID.".\n";
		return 0;
	}
	my $Version = "";
	my $Directory = $model->directory();
	if (defined($model->version())) {
		$Version = $model->version();
	}
	$ModelID = $model->id();

	#Printing the problem definition files for each false positive
	if (!defined($Stage)) {
		#Now we check that the reaction essentiality file exist
		if (!-e $Directory.$ModelID.$Version."-ReactionKOResult.txt") {
			print STDERR "FIGMODEL:GapGenerationAlgorithm: Reaction essentiality file not found for ".$ModelID.$Version.".\n";
			return 0;
		}
		#my $UniqueFilename = $self->filename();
		my $UniqueFilename = "CurrentSwift";

		#Determining the performance of the wildtype model
		my ($FalsePostives,$FalseNegatives,$CorrectNegatives,$CorrectPositives,$Errorvector,$HeadingVector) = $self->get_model($ModelID.$Version)->RunAllStudiesWithDataFast("All");
		PrintArrayToFile($Directory.$ModelID.$Version."-GGOPEM".".txt",[$HeadingVector,$Errorvector]);

		#Now we read in the reaction essentiality file
		my $EssentialityTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($Directory.$ModelID.$Version."-ReactionKOResult.txt",";","",0,["REACTION"]);

		#Identifying which reactions should not be knocked out by the gap generation
		my $ConservedList;
		for (my $i=0; $i < $EssentialityTable->size(); $i++) {
			if (($EssentialityTable->get_row($i)->{"FALSE NEGATIVES"}->[0] - $FalseNegatives) > 5) {
				push(@{$ConservedList},$EssentialityTable->get_row($i)->{"REACTION"}->[0]);
			}
		}
		my $NoKOList = join(";",@{$ConservedList});

		#Now we use the simulation output to make the gap generation run data
		my @Errors = split(/;/,$Errorvector);
		my @Headings = split(/;/,$HeadingVector);
		my $GapGenerationRunData;
		my $Count = 0;
		my $FileList;
		for (my $i=0; $i < @Errors; $i++) {
			if ($Errors[$i] == 2) {
				#Now we use the MFAToolkit to print a gap generation problem definition file for each false positive
				my @HeadingDataArray = split(/:/,$Headings[$i]);
				system($self->GenerateMFAToolkitCommandLineCall($UniqueFilename,$ModelID,$HeadingDataArray[1],["ProdGapGenerationPrint"],{"Reactions that should always be active" => $NoKOList,"Reactions to knockout" => $HeadingDataArray[3],"MFASolver" => "SCIP","Reactions that are always blocked" => "none"},$self->{"database message file directory"}->[0].$ModelID.$Version."-GG-".$i.".log",undef,$Version));
				#Copying the printed data to the gapgen prep directory
				my $OutputFile = $ModelID.$Version."_".$HeadingDataArray[0]."_".$HeadingDataArray[1]."_".$HeadingDataArray[2];
				$OutputFile =~ s/\s//;
				system("cp ".$self->{"MFAToolkit output directory"}->[0].$UniqueFilename."/CurrentProblem.lp /home/chenry/SwiftGapGen/".$Filename."/".$OutputFile.".lp");
				my $KeyTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->{"MFAToolkit output directory"}->[0].$UniqueFilename."/VariableKey.txt",";","|",0,undef);
				$KeyTable->headings(["Variable type","Variable ID"]);
				$KeyTable->save("/home/chenry/SwiftGapGen/".$Filename."/".$OutputFile.".key");
				push(@{$FileList},$OutputFile.".lp");
			}
		}
		PrintArrayToFile("/home/chenry/SwiftGapGen/".$Filename."/Joblist.txt",$FileList,1);
		#$self->cleardirectory($UniqueFilename);
	} else {
		#This code translates the solution files for each false positive into a single GGS file
		#Scheduling the testing
		system($self->{"scheduler executable"}->[0]." \"add:testsolutions?".$ModelID.$Version."?0?GG?1:BACK:fast:QSUB\"");
	}

	return 1;
}

=head3 IntegrateGrowMatchSolution
Definition:
	my $ChangeHash = $model->IntegrateGrowMatchSolution($ModelName,$NewModelFilename,$ReactionArrayRef,$DirectionArrayRef,$Note,$ClearCache,$PrintModel);
Description:
Example:

=cut

sub IntegrateGrowMatchSolution {
	my ($self,$ModelName,$NewModelFilename,$ReactionArray,$DirectionArray,$Note,$ClearCache,$PrintModel,$AddOnly) = @_;

	#Loading the original model
	if (defined($ClearCache) && $ClearCache == 1) {
		$self->database()->ClearDBModel($ModelName,"DELETE");
	}
	my $ModelTable = $self->database()->GetDBModel($ModelName);
	$ModelTable->add_headings("NOTES");
	if (!defined($ModelTable)) {
		print STDERR "FIGMODEL:IntegrateGrowMatchSolution: Could not load model data: ".$ModelName."\n";
		return undef;
	}

	#Getting the original model filename if no filename is supplied
	if (!defined($NewModelFilename)) {
		$NewModelFilename = $ModelTable->filename();
	}

	#Setting the note to "GrowMatch" if no note is provided
	if (!defined($Note)) {
		$Note = "GROWTHMATCH";
	}

	#Adding the reactions in the solution to a hash
	my $Changes;
	for (my $k=0; $k < @{$ReactionArray}; $k++) {
		my $Reaction = $ReactionArray->[$k];
		my $Direction = $DirectionArray->[$k];
		#Checking if the solution reaction is in the model
		my $Row = $ModelTable->get_row_by_key($Reaction,"LOAD");
		if (defined($Row)) {
			#If the reaction is already present, this is a gap generation reaction and should be removed
			if ($Row->{"DIRECTIONALITY"}->[0] eq "<=>") {
				#Making the gap generation reaction irreversible
				if ($Direction eq "=>" && (!defined($AddOnly) || $AddOnly == 0)) {
					$Row->{"DIRECTIONALITY"}->[0] = "<=";
					$Changes->{$Direction.$Reaction} = "CHANGED:<=";
				} elsif (!defined($AddOnly) || $AddOnly == 0) {
					$Row->{"DIRECTIONALITY"}->[0] = "=>";
					$Changes->{$Direction.$Reaction} = "CHANGED:=>";
				}
			} elsif ($Row->{"DIRECTIONALITY"}->[0] eq $Direction && (!defined($AddOnly) || $AddOnly == 0)) {
				#Removing the gap generation reaction entirely
				$ModelTable->delete_row($ModelTable->row_index($Row));
				$Changes->{$Direction.$Reaction} = "REMOVED";
			} else {
				#This is a reversibility gap filling reaction
				$Row->{"NOTES"}->[0] = "Directionality switched from ".$Row->{"DIRECTIONALITY"}->[0]." to <=> during gap filling process";
				$Row->{"DIRECTIONALITY"}->[0] = "<=>";
				$Changes->{$Direction.$Reaction} = "CHANGED:<=>";
			}
		} else {
			#If the reaction is not in the model, it is added
			$ModelTable->add_row({"LOAD" => [$Reaction], "DIRECTIONALITY" => [$Direction], "COMPARTMENT" => ["c"], "ASSOCIATED PEG" => [$Note], "SUBSYSTEM" => ["NONE"], "CONFIDENCE" => ["NONE"], "REFERENCE" => ["NONE"],"NOTES" => ["Reaction added during ".$Note]});
			$Changes->{$Direction.$Reaction} = "ADDED:".$Direction;
		}
	}
	#Printing the test model
	if (defined($PrintModel) && $PrintModel == 1) {
		$ModelTable->save($NewModelFilename);
	}
	return $Changes;
}

=head3 CombineAllReconciliation
Definition:
	$model->CombineAllReconciliation($ModelList);
Description:
Example:
	$model->CombineAllReconciliation(["Opt83333.1","Opt224308.1"]);
=cut

sub CombineAllReconciliation {
	my ($self,$ModelList,$Run,$SelectedSolutions,$OkayReactionsFile,$BlackListReactionsFile,$IntegrateSolution) = @_;

	#All final integrated solutions will be stored here
	my $FinalSolutions;

	#Reactions that need human attention will be posted here
	my $AttentionTable = ModelSEED::FIGMODEL::FIGMODELTable->new(["STATUS","KEY","DATABASE","DEFINITION","DELTAG","REVERSIBLITY","DIRECTION","CONFLICT","NUMBER OF SOLUTIONS"],"/home/chenry/AttentionTable.txt",["KEY"],";","|",undef);;
	$AttentionTable->add_row({"KEY" => ["SINGLET REACTIONS"],"DATABASE" => ["SINGLET REACTIONS"]});

	#Parsing selected solution file
	my %SolutionSelectHash;
	my %OkayReactions;
	my %BlackListReactions;
	if (-e $SelectedSolutions) {
		my $Data = LoadMultipleColumnFile($SelectedSolutions," ");
		for (my $i=0;$i < @{$Data}; $i++) {
			if (@{$Data->[$i]} >= 2) {
				$SolutionSelectHash{$Data->[$i]->[0]} = $Data->[$i]->[1];
			}
		}
	}
	if (-e $OkayReactionsFile) {
		my $Data = LoadSingleColumnFile($OkayReactionsFile," ");
		for (my $i=0;$i < @{$Data}; $i++) {
			$OkayReactions{$Data->[$i]} = 1;
		}
	}
	if (-e $BlackListReactionsFile) {
		my $Data = LoadSingleColumnFile($BlackListReactionsFile," ");
		for (my $i=0;$i < @{$Data}; $i++) {
			$BlackListReactions{$Data->[$i]} = 1;
		}
	}

	#All alternative sets stored in this hash
	my $Sets;
	my $SetHash;
	my $AlternativeHash;

	#All results will be stored in this combined table
	my $ResultTable = ModelSEED::FIGMODEL::FIGMODELTable->new(["KEY","DATABASE","DEFINITION","DELTAG","REVERSIBLITY","DIRECTION","CONFLICT","NUMBER OF SOLUTIONS"],"NONE",["KEY"],";","|",undef);
	$ResultTable->add_row({"KEY" => ["SINGLET REACTIONS"],"DATABASE" => ["SINGLET REACTIONS"]});

	#Scanning through the model list
	for (my $i=0; $i < @{$ModelList}; $i++) {
		my $ModelID = $ModelList->[$i];
		my $model = $self->get_model($ModelID);
		if (defined($model) && -e $model->directory().$ModelID."-".$Run."Reconciliation.txt") {
			if (defined($SolutionSelectHash{$ModelID})) {
				$ResultTable->add_headings(($ModelID." ".$SolutionSelectHash{$ModelID}));
				$AttentionTable->add_headings(($ModelID));
			}

			my $CurrentData = ModelSEED::FIGMODEL::FIGMODELTable::load_table($model->directory().$ModelID."-".$Run."Reconciliation.txt",";","",0,["DATABASE"]);
			my $CurrentAlternative = -1;
			my $AlternativeList;
			for (my $j=0; $j < $CurrentData->size(); $j++) {
				my $Row = $CurrentData->get_row($j);
				if (defined($Row->{"DATABASE"}->[0]) && $Row->{"DATABASE"}->[0] ne "SINGLET REACTIONS") {
					if ($Row->{"DATABASE"}->[0] eq "NEW SET") {
						if ($CurrentAlternative == -1) {
							$AttentionTable->add_row({"KEY" => ["SINGLET REACTIONS"],"DATABASE" => ["SELECTED ALTERNATIVES"]});
						}
						if ($CurrentAlternative != -1 && defined($AlternativeList)) {
							#Checking if set has been observed before
							my $Set = undef;
							my $AcceptableSolutionFound = -1;
							my $AcceptableKey;
							my $KeyList;
							my $GoodSolution = 0;
							for (my $k=0; $k < @{$AlternativeList}; $k++) {
								if (defined($AlternativeList->[$k])) {
									$GoodSolution++;
									#Saving the set
									my $Key = join(",",sort(@{$AlternativeList->[$k]}));
									push(@{$KeyList},$Key);
									if (!defined($Set) && defined($SetHash->{$Key})) {
										$Set = $SetHash->{$Key};
									}
									#Checking if the solution contains conflict reactions or blacklist reactions
									if (defined($SolutionSelectHash{$ModelID}) && $AcceptableSolutionFound == -1) {
										$AcceptableSolutionFound = $k;
										$AcceptableKey = $Key;
										for (my $m=0; $m < @{$AlternativeList->[$k]}; $m++) {
											if (defined($BlackListReactions{$AlternativeList->[$k]->[$m]}) || ($AlternativeHash->{$AlternativeList->[$k]->[$m]}->{"REVERSIBLITY"}->[0] ne $AlternativeHash->{$AlternativeList->[$k]->[$m]}->{"DIRECTION"}->[0] && $AlternativeHash->{$AlternativeList->[$k]->[$m]}->{"REVERSIBLITY"}->[0] ne "<=>" && !defined($OkayReactions{$AlternativeList->[$k]->[$m]}))) {
												$AcceptableSolutionFound = -1;
												last;
											}
										}
									}
								}
							}
							my $New = 0;
							if (!defined($Set)) {
								$New = 1;
							}
							#Now checking if set contains all of the alternatives
							my $NewAcceptableSolution = 0;
							if ($GoodSolution > 0 && defined($SolutionSelectHash{$ModelID}) && $AcceptableSolutionFound == -1) {
								#Adding a new "no good alternative" section to the attention table if a matching section does not already exist
								$AcceptableKey = join(",",sort(@{$KeyList}));
								if (!defined($AttentionTable->get_row_by_key($AcceptableKey,"KEY"))) {
									$NewAcceptableSolution = 1;
									$AttentionTable->add_row({"KEY" => [$AcceptableKey],"DATABASE" => ["NO ACCEPTABLE SOLUTION"]});
								}
							} elsif ($GoodSolution > 0 && defined($SolutionSelectHash{$ModelID})) {
								if (!defined($AttentionTable->get_row_by_key($AcceptableKey,"KEY"))) {
									$NewAcceptableSolution = 1;
									$AttentionTable->add_row({"KEY" => [$AcceptableKey],"DATABASE" => ["ACCEPTABLE SOLUTION"]});
								}
							}
							for (my $k=0; $k < @{$AlternativeList}; $k++) {
								if (defined($AlternativeList->[$k])) {
									if (defined($SolutionSelectHash{$ModelID})) {
										if ($AcceptableSolutionFound == -1 && $NewAcceptableSolution == 1) {
											#Adding a new "no good alternative" section to the attention table if a matching section does not already exis
											$AttentionTable->add_row({"KEY" => [$AcceptableKey],"DATABASE" => ["ALTERNATIVE"]});
											for (my $m=0; $m < @{$AlternativeList->[$k]}; $m++) {
												my $NewRow = $AlternativeHash->{$AlternativeList->[$k]->[$m]};
												my $OriginalKey = $NewRow->{"KEY"}->[0];
												$NewRow->{"KEY"}->[0] = $NewRow->{"DATABASE"}->[0].$NewRow->{"DIRECTION"}->[0];
												my $AttentionRow = $AttentionTable->add_row_copy($NewRow);
												$NewRow->{"KEY"}->[0] = $OriginalKey;
												$AttentionRow->{$ModelID} = 1;
											}
										} elsif ($AcceptableSolutionFound == $k) {
											for (my $m=0; $m < @{$AlternativeList->[$k]}; $m++) {
												my $NewRow = $AlternativeHash->{$AlternativeList->[$k]->[$m]};
												if ($Run eq "GG" || ($NewRow->{"REVERSIBLITY"}->[0] ne $NewRow->{"DIRECTION"}->[0] && $NewRow->{"REVERSIBLITY"}->[0] ne "<=>")) {
													($FinalSolutions->{$ModelID},my $Dummy) = AddElementsUnique($FinalSolutions->{$ModelID},$NewRow->{"DATABASE"}->[0].";".$NewRow->{"DIRECTION"}->[0]);
												} else {
													($FinalSolutions->{$ModelID},my $Dummy) = AddElementsUnique($FinalSolutions->{$ModelID},$NewRow->{"DATABASE"}->[0].";".$NewRow->{"REVERSIBLITY"}->[0]);
												}
												my $AttentionRow;
												if ($NewAcceptableSolution == 1) {
													my $OriginalKey = $NewRow->{"KEY"}->[0];
													$NewRow->{"KEY"}->[0] = $NewRow->{"DATABASE"}->[0].$NewRow->{"DIRECTION"}->[0]."|".$AcceptableKey;
													$AttentionRow = $AttentionTable->add_row_copy($NewRow);
													$NewRow->{"KEY"}->[0] = $OriginalKey;
												} else {
													$AttentionRow = $AttentionTable->get_row_by_key($NewRow->{"DATABASE"}->[0].$NewRow->{"DIRECTION"}->[0]."|".$AcceptableKey,"KEY");
												}
												$AttentionRow->{$ModelID} = 1;
											}
										}
									}

									my $Key = join(",",sort(@{$AlternativeList->[$k]}));
									if (!defined($SetHash->{$Key})) {
										push(@{$Set},$AlternativeList->[$k]);
										$SetHash->{$Key} = $Set;
									}
								}
							}
							if ($New == 1) {
								push(@{$Sets},$Set);
							}
						}
						$AlternativeList = ();
						$CurrentAlternative = 0;
					} elsif ($Row->{"DATABASE"}->[0] eq "ALTERNATIVE SET") {
						$CurrentAlternative++;
					} elsif ($Row->{"DATABASE"}->[0] =~ m/rxn\d\d\d\d\d/) {
						if (!defined($SolutionSelectHash{$ModelID}) || defined($Row->{"Solution ".$SolutionSelectHash{$ModelID}})) {
							if ($CurrentAlternative == -1) {
								my $NewRow = $ResultTable->get_row_by_key($Row->{"DATABASE"}->[0].$Row->{"DIRECTION"}->[0],"KEY");
								if (!defined($NewRow)) {
									$NewRow = {"KEY" => [$Row->{"DATABASE"}->[0].$Row->{"DIRECTION"}->[0]],"DATABASE" => [$Row->{"DATABASE"}->[0]],"DEFINITION" => [$Row->{"DEFINITION"}->[0]],"DELTAG" => [$Row->{"DELTAG"}->[0]],"REVERSIBLITY" => [$Row->{"REVERSIBLITY"}->[0]],"DIRECTION" => [$Row->{"DIRECTION"}->[0]],"NUMBER OF SOLUTIONS" => [0]};
									$ResultTable->add_row($NewRow);
									if ($NewRow->{"REVERSIBLITY"}->[0] eq "=>" && $NewRow->{"DIRECTION"}->[0] eq "<=") {
										$NewRow->{"CONFLICT"}->[0] = "YES";
									} elsif ($NewRow->{"REVERSIBLITY"}->[0] eq "<=" && $NewRow->{"DIRECTION"}->[0] eq "=>") {
										$NewRow->{"CONFLICT"}->[0] = "YES";
									}
								}

								my $Count = 0;
								for (my $n=6; $n < $CurrentData->headings(); $n++) {
									if (defined($Row->{"Solution ".$Count}->[0])) {
										$NewRow->{"NUMBER OF SOLUTIONS"}->[0]++;
										$NewRow->{$ModelID." ".$Count}->[0] = $Row->{"Solution ".$Count}->[0];
										if (!defined($SolutionSelectHash{$ModelID})) {
											$ResultTable->add_headings(($ModelID." ".$Count));
										} elsif ($SolutionSelectHash{$ModelID} == $Count) {
											if (defined($NewRow->{"CONFLICT"}->[0]) && $NewRow->{"CONFLICT"}->[0] eq "YES") {
												$NewRow->{"STATUS"}->[0] = "INFEASIBLE";
												my $AttentionRow = $AttentionTable->get_row_by_key($NewRow->{"DATABASE"}->[0].$NewRow->{"DIRECTION"}->[0],"KEY");
												if (!defined($AttentionRow)) {
													$AttentionTable->add_row($NewRow,0);
													$AttentionRow = $NewRow;
												}
												$AttentionRow->{$ModelID}->[0] = $Row->{"Solution ".$Count}->[0];
												if (defined($OkayReactions{$AttentionRow->{"DATABASE"}->[0].$AttentionRow->{"DIRECTION"}->[0]})) {
													$AttentionRow->{"STATUS"}->[0] = "OKAY LIST";
													if ($Run eq "GF") {
														($FinalSolutions->{$ModelID},my $Dummy) = AddElementsUnique($FinalSolutions->{$ModelID},$AttentionRow->{"DATABASE"}->[0].";<=>");
													} else {
														($FinalSolutions->{$ModelID},my $Dummy) = AddElementsUnique($FinalSolutions->{$ModelID},$AttentionRow->{"DATABASE"}->[0].";".$AttentionRow->{"DIRECTION"}->[0]);
													}
												}
											} elsif (defined($BlackListReactions{$NewRow->{"DATABASE"}->[0].$NewRow->{"DIRECTION"}->[0]})) {
												$NewRow->{"STATUS"}->[0] = "BLACKLIST";
												my $AttentionRow = $AttentionTable->get_row_by_key($NewRow->{"DATABASE"}->[0].$NewRow->{"DIRECTION"}->[0],"KEY");
												if (!defined($AttentionRow)) {
													$AttentionTable->add_row($NewRow,0);
													$AttentionRow = $NewRow;
												}
												$AttentionRow->{$ModelID}->[0] = $Row->{"Solution ".$Count}->[0];
											} else {
												if ($Run eq "GF") {
													($FinalSolutions->{$ModelID},my $Dummy) = AddElementsUnique($FinalSolutions->{$ModelID},$NewRow->{"DATABASE"}->[0].";".$NewRow->{"REVERSIBLITY"}->[0]);
												} else {
													($FinalSolutions->{$ModelID},my $Dummy) = AddElementsUnique($FinalSolutions->{$ModelID},$NewRow->{"DATABASE"}->[0].";".$NewRow->{"DIRECTION"}->[0]);
												}
											}
										}
									}
									$Count++;
								}
							} else {
								push(@{$AlternativeList->[$CurrentAlternative]},$Row->{"DATABASE"}->[0].$Row->{"DIRECTION"}->[0]);
								if (!defined($AlternativeHash->{$Row->{"DATABASE"}->[0].$Row->{"DIRECTION"}->[0]})) {
									$AlternativeHash->{$Row->{"DATABASE"}->[0].$Row->{"DIRECTION"}->[0]} = $Row;
								}
								my $NewRow = $AlternativeHash->{$Row->{"DATABASE"}->[0].$Row->{"DIRECTION"}->[0]};
								my $Count = 0;
								for (my $n=6; $n < $CurrentData->headings(); $n++) {
									if (defined($Row->{"Solution ".$Count}->[0])) {
										$NewRow->{"NUMBER OF SOLUTIONS"}->[0]++;
										$NewRow->{$ModelID." ".$Count}->[0] = $Row->{"Solution ".$Count}->[0];
										if (!defined($SolutionSelectHash{$ModelID})) {
											$ResultTable->add_headings(($ModelID." ".$Count));
										}
									}
									$Count++;
								}
							}
						}
					}
				}
			}
			#Adding final reaction set if there is one
			if ($CurrentAlternative != -1 && defined($AlternativeList)) {
				#Checking if set has been observed before
				my $Set = undef;
				my $AcceptableSolutionFound = -1;
				my $AcceptableKey;
				my $KeyList;
				my $GoodSolution = 0;
				for (my $k=0; $k < @{$AlternativeList}; $k++) {
					if (defined($AlternativeList->[$k])) {
						$GoodSolution++;
						#Saving the set
						my $Key = join(",",sort(@{$AlternativeList->[$k]}));
						push(@{$KeyList},$Key);
						if (!defined($Set) && defined($SetHash->{$Key})) {
							$Set = $SetHash->{$Key};
						}
						#Checking if the solution contains conflict reactions or blacklist reactions
						if (defined($SolutionSelectHash{$ModelID}) && $AcceptableSolutionFound == -1) {
							$AcceptableSolutionFound = $k;
							$AcceptableKey = $Key;
							for (my $m=0; $m < @{$AlternativeList->[$k]}; $m++) {
								if (defined($BlackListReactions{$AlternativeList->[$k]->[$m]}) || ($AlternativeHash->{$AlternativeList->[$k]->[$m]}->{"REVERSIBLITY"}->[0] ne $AlternativeHash->{$AlternativeList->[$k]->[$m]}->{"DIRECTION"}->[0] && $AlternativeHash->{$AlternativeList->[$k]->[$m]}->{"REVERSIBLITY"}->[0] ne "<=>" && !defined($OkayReactions{$AlternativeList->[$k]->[$m]}))) {
									$AcceptableSolutionFound = -1;
									last;
								}
							}
						}
					}
				}
				my $New = 0;
				if (!defined($Set)) {
					$New = 1;
				}
				#Now checking if set contains all of the alternatives
				my $NewAcceptableSolution = 0;
				if ($GoodSolution > 0 && defined($SolutionSelectHash{$ModelID}) && $AcceptableSolutionFound == -1) {
					#Adding a new "no good alternative" section to the attention table if a matching section does not already exist
					$AcceptableKey = join(",",sort(@{$KeyList}));
					if (!defined($AttentionTable->get_row_by_key($AcceptableKey,"KEY"))) {
						$NewAcceptableSolution = 1;
						$AttentionTable->add_row({"KEY" => [$AcceptableKey],"DATABASE" => ["NO ACCEPTABLE SOLUTION"]});
					}
				} elsif ($GoodSolution > 0 && defined($SolutionSelectHash{$ModelID})) {
					if (!defined($AttentionTable->get_row_by_key($AcceptableKey,"KEY"))) {
						$NewAcceptableSolution = 1;
						$AttentionTable->add_row({"KEY" => [$AcceptableKey],"DATABASE" => ["ACCEPTABLE SOLUTION"]});
					}
				}
				for (my $k=0; $k < @{$AlternativeList}; $k++) {
					if (defined($AlternativeList->[$k])) {
						if (defined($SolutionSelectHash{$ModelID})) {
							if ($AcceptableSolutionFound == -1 && $NewAcceptableSolution == 1) {
								#Adding a new "no good alternative" section to the attention table if a matching section does not already exis
								$AttentionTable->add_row({"KEY" => [$AcceptableKey],"DATABASE" => ["ALTERNATIVE"]});
								for (my $m=0; $m < @{$AlternativeList->[$k]}; $m++) {
									my $NewRow = $AlternativeHash->{$AlternativeList->[$k]->[$m]};
									my $OriginalKey = $NewRow->{"KEY"}->[0];
									$NewRow->{"KEY"}->[0] = $NewRow->{"DATABASE"}->[0].$NewRow->{"DIRECTION"}->[0];
									my $AttentionRow = $AttentionTable->add_row_copy($NewRow);
									$NewRow->{"KEY"}->[0] = $OriginalKey;
									$AttentionRow->{$ModelID} = 1;
								}
							} elsif ($AcceptableSolutionFound == $k) {
								for (my $m=0; $m < @{$AlternativeList->[$k]}; $m++) {
									my $NewRow = $AlternativeHash->{$AlternativeList->[$k]->[$m]};
									if ($Run eq "GG" || ($NewRow->{"REVERSIBLITY"}->[0] ne $NewRow->{"DIRECTION"}->[0] && $NewRow->{"REVERSIBLITY"}->[0] ne "<=>")) {
										($FinalSolutions->{$ModelID},my $Dummy) = AddElementsUnique($FinalSolutions->{$ModelID},$NewRow->{"DATABASE"}->[0].";".$NewRow->{"DIRECTION"}->[0]);
									} else {
										($FinalSolutions->{$ModelID},my $Dummy) = AddElementsUnique($FinalSolutions->{$ModelID},$NewRow->{"DATABASE"}->[0].";".$NewRow->{"REVERSIBLITY"}->[0]);
									}
									my $AttentionRow;
									if ($NewAcceptableSolution == 1) {
										my $OriginalKey = $NewRow->{"KEY"}->[0];
										$NewRow->{"KEY"}->[0] = $NewRow->{"DATABASE"}->[0].$NewRow->{"DIRECTION"}->[0]."|".$AcceptableKey;
										$AttentionRow = $AttentionTable->add_row_copy($NewRow);
										$NewRow->{"KEY"}->[0] = $OriginalKey;
									} else {
										$AttentionRow = $AttentionTable->get_row_by_key($NewRow->{"DATABASE"}->[0].$NewRow->{"DIRECTION"}->[0]."|".$AcceptableKey,"KEY");
									}
									$AttentionRow->{$ModelID} = 1;
								}
							}
						}

						my $Key = join(",",sort(@{$AlternativeList->[$k]}));
						if (!defined($SetHash->{$Key})) {
							push(@{$Set},$AlternativeList->[$k]);
							$SetHash->{$Key} = $Set;
						}
					}
				}
				if ($New == 1) {
					push(@{$Sets},$Set);
				}
			}
			#Printing the growmatch solution file
			if (defined($SolutionSelectHash{$ModelID}) && defined($FinalSolutions->{$ModelID})) {
				PrintArrayToFile($model->directory().$ModelID."-".$Run."-FinalSolution.txt",$FinalSolutions->{$ModelID});
				if (defined($IntegrateSolution) && $IntegrateSolution == 1) {
					if ($Run eq "GF") {
						system($self->{"Model driver executable"}->[0]." \"integrategrowmatchsolution?".$ModelID."?".$ModelID."-".$Run."-FinalSolution.txt?".$model->id()."VGapFilled.txt\"");
					} elsif ($Run eq "GG") {
						system($self->{"Model driver executable"}->[0]." \"integrategrowmatchsolution?".$ModelID."?".$ModelID."-".$Run."-FinalSolution.txt?".$model->id()."VOptimized.txt\"");
					}
				}
			}
		} else {
			print $model->directory().$ModelID."-".$Run."Reconciliation.txt file not found!\n";
		}
	}

	#Adding the alternative sets to the table
	for (my $i=0; $i < @{$Sets}; $i++) {
		for (my $j=0; $j < @{$Sets->[$i]}; $j++) {
			if ($j == 0) {
				$ResultTable->add_row({"KEY" => ["New set"],"DATABASE" => ["NEW SET"]});
			} else {
				$ResultTable->add_row({"KEY" => ["Alt set"],"DATABASE" => ["ALTERNATE SET"]});
			}
			for (my $k=0; $k < @{$Sets->[$i]->[$j]}; $k++) {
				my $Row = $AlternativeHash->{$Sets->[$i]->[$j]->[$k]};
				$Row->{"KEY"}->[0] = $Row->{"DATABASE"}->[0].$Row->{"DIRECTION"}->[0];
				$ResultTable->add_row($Row);
			}
		}
	}

	#Marking conflicts
	for (my $i=0; $i < $ResultTable->size(); $i++) {
		my $Row = $ResultTable->get_row($i);
		if (defined($Row->{"DATABASE"}->[0]) && $Row->{"DATABASE"}->[0] =~ m/rxn\d\d\d\d\d/) {
			if ($Row->{"REVERSIBLITY"}->[0] eq "=>" && $Row->{"DIRECTION"}->[0] eq "<=") {
				$Row->{"CONFLICT"}->[0] = "YES";
			} elsif ($Row->{"REVERSIBLITY"}->[0] eq "<=" && $Row->{"DIRECTION"}->[0] eq "=>") {
				$Row->{"CONFLICT"}->[0] = "YES";
			}
		}
	}

	$AttentionTable->save();

	return $ResultTable;
}

=head2 CGI Methods

=head3 SubsystemLinks

Definition:
	my ($Link) = $model->SubsystemLinks($Subsystem,$SelectedModel);

Description:


Example:
	my ($Link) = $model->SubsystemLinks($Subsystem,$SelectedModel);

=cut

sub SubsystemLinks {
	my ($self,$Subsystem,$SelectedModel) = @_;

	my $NeatSubsystem = $Subsystem;
	$NeatSubsystem =~ s/\_/ /g;
	return '<a style="text-decoration:none" href="?page=Subsystems&subsystem='.$Subsystem.'">'.$NeatSubsystem."</a>";
}

=head3 ScenarioLinks

Definition:
	my ($Link) = $model->ScenarioLinks($Subsystem);

Description:


Example:
	my ($Link) = $model->ScenarioLinks($Subsystem);

=cut

sub ScenarioLinks {
	my ($self,$Scenario) = @_;

	my @Temp = split(/:/,$Scenario);
	shift(@Temp);

	return join(":",@Temp);
}

=head3 MapLinks

Definition:
	my ($Link) = $model->MapLinks($Map,$ReactionList);

Description:


Example:
	my ($Link) = $model->MapLinks($Map,$ReactionList);

=cut

sub MapLinks {
	my ($self,$Map,$ReactionList) = @_;

	return '<a style="text-decoration:none" href="http://www.genome.jp/dbget-bin/show_pathway?'.$Map."+".join("+",@{$ReactionList}).'">'.$self->name_of_keggmap($Map)."</a>";
}

=head3 RxnLinks

Definition:
	my ($Link) = $model->RxnLinks($RxnID,$SelectedModel,$Label);

Description:
	This function returns the link for the reaction viewer page given a reaction ID.

Example:
	my ($Link) = $model->RxnLinks($RxnID,$SelectedModel,$Label);

=cut

sub RxnLinks {
	my ($self,$RxnID,$SelectedModel,$Label) = @_;

	if (!defined($Label) || $Label eq "IDONLY" || !defined($self->{"DATABASE"}->{"REACTIONHASH"}->{$RxnID}) || !defined($self->{"DATABASE"}->{"REACTIONHASH"}->{$RxnID}->{"NAME"})) {
		if (defined($SelectedModel)) {
			return '<a href="?page=ReactionViewer&reaction='.$RxnID.'&model='.$SelectedModel.'">'.$RxnID."</a>";
		} else {
			return '<a href="?page=ReactionViewer&reaction='.$RxnID.'">'.$RxnID."</a>";
		}
	}

	if ($Label eq "NAME") {
	return '<a style="text-decoration:none" href="?page=ReactionViewer&reaction='.$RxnID.'&model='.$SelectedModel.'" title="'.$RxnID.'">'.$self->{"DATABASE"}->{"REACTIONHASH"}->{$RxnID}->{"NAME"}->[0]."</a>";
	} else {
	return '<a style="text-decoration:none" href="?page=ReactionViewer&reaction='.$RxnID.'&model='.$SelectedModel.'" title="'.$self->{"DATABASE"}->{"REACTIONHASH"}->{$RxnID}->{"NAME"}->[0].'">'.$RxnID."</a>";
	}
}

sub GenomeLink {
	my ($self,$GenomeID) = @_;

	return '<a style="text-decoration:none" href="?page=Organism&organism='.$GenomeID.'" title="">'.$GenomeID."</a>";
}

sub ParseForLinks {
	my ($self,$Text,$SelectedModel,$LinkType) = @_;

	my %VisitedLinks;

	#Searching for PFAM IDs as defined by initial "PF" string
	#Seaver
	$_ = $Text;
	my @OriginalArray = /(PF\d*)/g;
	for (my $i=0; $i < @OriginalArray; $i++) {
		if (!defined($VisitedLinks{$OriginalArray[$i]})) {
			$VisitedLinks{$OriginalArray[$i]} = 1;
			my $Link = $self->PFAMLinks($OriginalArray[$i]);
			my $Find = $OriginalArray[$i];
			$Text =~ s/$Find/$Link/g;
		}
	}

	#Searching for PubMed IDs as defined by initial "pubmed:" string
	#Seaver
	$_ = $Text;
	@OriginalArray = /(pubmed:\d*)/g;
	for (my $i=0; $i < @OriginalArray; $i++) {
		if (!defined($VisitedLinks{$OriginalArray[$i]})) {
			$VisitedLinks{$OriginalArray[$i]} = 1;
			my $Link = $self->PubMedLinks($OriginalArray[$i]);
			my $Find = $OriginalArray[$i];
			$Text =~ s/$Find/$Link/g;
		}
	}
	

	#Searching for MaizeSequence.org IDs
	$_ = uc($Text);
	@OriginalArray = /^((?:GRMZM\dG\d{6}(?:_[TP]\d{2})?)|(?:AC\d{6}\.\d_FG[TP]?\d{3}))/g;
	for (my $i=0; $i < @OriginalArray; $i++) {
		if (!defined($VisitedLinks{$OriginalArray[$i]})) {
			$VisitedLinks{$OriginalArray[$i]} = 1;
			#prevent KEGG compound ID from being picked up
			$VisitedLinks{substr($OriginalArray[$i],1,6)} = 1;
			my $Link = $self->MaizeSeqLinks($OriginalArray[$i]);
			my $Find = $OriginalArray[$i];
			$Text =~ s/$Find/$Link/g;
		}
	}

	#Searching for NCBI IDs
	$_ = $Text;
	@OriginalArray = /(N[PM]_\d{9})/g;
	for (my $i=0; $i < @OriginalArray; $i++) {
		if (!defined($VisitedLinks{$OriginalArray[$i]})) {
			$VisitedLinks{$OriginalArray[$i]} = 1;
			my $Link = $self->NCBILinks($OriginalArray[$i]);
			my $Find = $OriginalArray[$i];
			$Text =~ s/$Find/$Link/g;
		}
	}

	#Searching for NCBI Entrez Gene IDs
	$_ = $Text;
	@OriginalArray = /(LOC\d{9})/g;
	for (my $i=0; $i < @OriginalArray; $i++) {
		if (!defined($VisitedLinks{$OriginalArray[$i]})) {
			$VisitedLinks{$OriginalArray[$i]} = 1;
			#prevent KEGG compound ID from being picked up
			$VisitedLinks{substr($OriginalArray[$i],2,6)} = 1;
			my $Link = $self->EntrezGeneLinks($OriginalArray[$i]);
			my $Find = $OriginalArray[$i];
			$Text =~ s/$Find/$Link/g;
		}
	}

	#Searching for TAIR ID search links
	$_ = $Text;
	@OriginalArray = /(A[Tt]\d[Gg]\d{5})/g;
	for (my $i=0; $i < @OriginalArray; $i++) {
		if (!defined($VisitedLinks{$OriginalArray[$i]})) {
			$VisitedLinks{$OriginalArray[$i]} = 1;
			my $Link = $self->TAIRGeneLinks($OriginalArray[$i]);
			my $Find = $OriginalArray[$i];
			$Text =~ s/$Find/$Link/g;
		}
	}

	#Searching for KEGG EC number links
	$_ = $Text;
	@OriginalArray = /(\d+\.\d+.\d+\.\d+)/g;
	for (my $i=0; $i < @OriginalArray; $i++) {
		if (!defined($VisitedLinks{$OriginalArray[$i]})) {
			$VisitedLinks{$OriginalArray[$i]} = 1;
			my $Link = $self->KEGGECLinks($OriginalArray[$i]);
			my $Find = $OriginalArray[$i];
			$Text =~ s/$Find(\D)/$Link$1/g;
			$Text =~ s/$Find$/$Link/g;
		}
	}

	#Searching for MaizeCyc (maybe all Cyc) reactions using "RXN"
	#Seaver
	$_ = $Text;
	@OriginalArray = /([\w\-\.]*(?:-RXN)|(?:RXN\d{0,3}[A-Z]{0,2}-)[\w\-\.]*)/g;
	for (my $i=0; $i < @OriginalArray; $i++) {
		if (!defined($VisitedLinks{$OriginalArray[$i]})) {
			$VisitedLinks{$OriginalArray[$i]} = 1;
			my $Link = $self->MaizeCycLinks($OriginalArray[$i]);
			my $Find = $OriginalArray[$i];
			$Text =~ s/$Find/$Link/g;
		}
	}

	#Searching for rxn links
	$_ = $Text;
	@OriginalArray = /(rxn\d\d\d\d\d)/g;
	for (my $i=0; $i < @OriginalArray; $i++) {
		if (!defined($VisitedLinks{$OriginalArray[$i]})) {
			$VisitedLinks{$OriginalArray[$i]} = 1;
			my $Link = $self->RxnLinks($OriginalArray[$i],$SelectedModel,$LinkType);
			my $Find = $OriginalArray[$i];
			$Text =~ s/$Find/$Link/g;
		}
	}
	$_ = $Text;
	@OriginalArray = /(bio\d\d\d\d\d)/g;
	for (my $i=0; $i < @OriginalArray; $i++) {
		if (!defined($VisitedLinks{$OriginalArray[$i]})) {
			$VisitedLinks{$OriginalArray[$i]} = 1;
			my $Link = $self->RxnLinks($OriginalArray[$i],$SelectedModel,$LinkType);
			my $Find = $OriginalArray[$i];
			$Text =~ s/$Find/$Link/g;
		}
	}
	#Searching for cpd links
	$_ = $Text;
	@OriginalArray = /(cpd\d\d\d\d\d)/g;
	for (my $i=0; $i < @OriginalArray; $i++) {
		if (!defined($VisitedLinks{$OriginalArray[$i]})) {
			$VisitedLinks{$OriginalArray[$i]} = 1;
			my $Link = $self->CpdLinks($OriginalArray[$i],$SelectedModel,$LinkType);
			my $Find = $OriginalArray[$i];
			$Text =~ s/$Find/$Link/g;
		}
	}
	#Searching for peg links
	if (defined($SelectedModel)) {
		$_ = $Text;
		@OriginalArray = /(peg\.\d+)/g;
		for (my $i=0; $i < @OriginalArray; $i++) {
			if (!defined($VisitedLinks{$OriginalArray[$i]})) {
				$VisitedLinks{$OriginalArray[$i]} = 1;
				my $Link = $self->web()->gene_link($OriginalArray[$i],$SelectedModel);
				my $Find = $OriginalArray[$i];
				$Text =~ s/$Find(\D)/$Link$1/g;
				$Text =~ s/$Find$/$Link/g;
			}
		}
	} else {
		if ($Text =~ m/^(fig\|\d+\.\d+\.peg\.\d+)$/) {
			$Text = '<a href="http://www.theseed.org/linkin.cgi?id='.$Text.'" target="_blank">'.$Text."</a>";
		}
	}

	#Searching for KEGG compound links
	$_ = $Text;
	@OriginalArray = /(C\d\d\d\d\d)/g;
	for (my $i=0; $i < @OriginalArray; $i++) {
		if (!defined($VisitedLinks{$OriginalArray[$i]})) {
			$VisitedLinks{$OriginalArray[$i]} = 1;
			my $Link = $self->KEGGCompoundLinks($OriginalArray[$i]);
			my $Find = $OriginalArray[$i];
			$Text =~ s/$Find/$Link/g;
		}
	}
	#Searching for KEGG reaction links
	$_ = $Text;
	@OriginalArray = /(R\d\d\d\d\d)/g;
	for (my $i=0; $i < @OriginalArray; $i++) {
		if (!defined($VisitedLinks{$OriginalArray[$i]})) {
			$VisitedLinks{$OriginalArray[$i]} = 1;
			my $Link = $self->KEGGReactionLinks($OriginalArray[$i]);
			my $Find = $OriginalArray[$i];
			$Text =~ s/$Find/$Link/g;
		}
	}

	return $Text;
}

=head3 ProcessIDList
Definition:
	(HashRef::TypeList) = $model->ProcessIDList(IDList)
Description:
	This function parses the input ID list and returns parsed IDs in a hash ref of the ID types
Example:
=cut

sub ProcessIDList {
	my ($self,$IDList) = @_;

	#Converting the $IDList into a flat array ref of IDs
	my $NewIDList;
	if (defined($IDList) && ref($IDList) ne 'ARRAY') {
		my @TempArray = split(/,/,$IDList);
		for (my $j=0; $j < @TempArray; $j++) {
			push(@{$NewIDList},$TempArray[$j]);
		}
	} elsif (defined($IDList)) {
		for (my $i=0; $i < @{$IDList}; $i++) {
			my @TempArray = split(/,/,$IDList->[$i]);
			for (my $j=0; $j < @TempArray; $j++) {
				push(@{$NewIDList},$TempArray[$j]);
			}
		}
	}

	#Determining the type of each ID
	my $TypeLists;
	if (defined($NewIDList)) {
		for (my $i=0; $i < @{$NewIDList}; $i++) {
			if ($NewIDList->[$i] ne "ALL") {
				if ($NewIDList->[$i] =~ m/^fig\|(\d+\.\d+)\.(.+)$/) {
					push(@{$TypeLists->{"FEATURES"}->{$1}},$2);
				} elsif ($NewIDList->[$i] =~ m/^figint\|(\d+\.\d+)\.(.+)$/) {
					push(@{$TypeLists->{"INTERVALS"}->{$1}},$2);
				} elsif ($NewIDList->[$i] =~ m/^figstr\|(\d+\.\d+)\.(.+)$/) {
					push(@{$TypeLists->{"STRAINS"}->{$1}},$2);
				} elsif ($NewIDList->[$i] =~ m/^figmodel\|(.+)$/) {
					my $ModelID = $1;
					my $ModelData = $self->get_model($ModelID);
					if (defined($ModelData)) {
						$TypeLists->{"MODELS"}->{$ModelID} = $ModelData;
					}
				} elsif ($NewIDList->[$i] =~ m/^fig\|(\d+\.\d+)$/ || $NewIDList->[$i] =~ m/^(\d+\.\d+)$/) {
					push(@{$TypeLists->{"GENOMES"}},$1);
				} elsif ($NewIDList->[$i] =~ m/^(rxn\d\d\d\d\d)$/) {
					push(@{$TypeLists->{"REACTIONS"}},$1);
				} elsif ($NewIDList->[$i] =~ m/^(cpd\d\d\d\d\d)$/) {
					push(@{$TypeLists->{"COMPOUNDS"}},$1);
				} else {
					my $ModelData = $self->get_model($NewIDList->[$i]);
					if (defined($ModelData)) {
						$TypeLists->{"MODELS"}->{$NewIDList->[$i]} = $ModelData;
					} else {
						push(@{$TypeLists->{"ATTRIBUTES"}},$1);
					}
				}
			}
		}
	}

	return $TypeLists;
}

sub CreateLink {
	my ($self,$ID,$ObjectType,$Parameter) = @_;

	if ($ObjectType eq "model") {
		return '<a style="text-decoration:none" href="javascript: SubmitModelSelection(\''.$ID.'\');">'.$ID."</a>";
	} elsif ($ObjectType eq "pubmed") {
		return '<a style="text-decoration:none" href="http://www.ncbi.nlm.nih.gov/pubmed/'.substr($ID,4).'" target="_blank">'.$ID."</a>";
	} elsif ($ObjectType eq "peg ID" || $ObjectType eq "Gene ID") {
		return '<a href="linkin.cgi?id=fig|'.$Parameter.".".$ID.'" target="_blank">'.$ID."</a>";
	} elsif ($ObjectType eq "Genome ID") {
		return '<a href="seedviewer.cgi?page=Organism&organism='.$ID.'" target="_blank">'.$ID."</a>";
	} elsif ($ObjectType eq "Subsystems") {
		return '<a href="seedviewer.cgi?page=Subsystems&subsystem='.$ID.'&organism='.$Parameter.'" target="_blank">'.$ID."</a>";
	} elsif ($ID =~ m/^rxn\d\d\d\d\d$/) {
		return '<a href="seedviewer.cgi?page=ReactionViewer&reaction='.$ID.'" target="_blank">'.$ID."</a>";
	} elsif ($ObjectType eq "genelist") {
		return '<a style="text-decoration:none" href="seedviewer.cgi?page=GeneViewer&id='.$Parameter.'" target="_blank">'.$ID."</a>";
	} elsif ($ObjectType eq "reactionlist") {
		return '<a style="text-decoration:none" href="seedviewer.cgi?page=ReactionViewer&model='.$Parameter.'" target="_blank">'.$ID."</a>";
	} elsif ($ObjectType eq "compoundlist") {
		return '<a style="text-decoration:none" href="seedviewer.cgi?page=CompoundViewer&model='.$Parameter.'" target="_blank">'.$ID."</a>";
	}

	return $ID;
}

sub MaizeCycLinks{
   my ($self,$ID) = @_;
   return '<a href="http://pathway-dev.gramene.org/MAIZE/new-image?object='.$ID.'">'.$ID.'</a>';
}

sub PFAMLinks{
   my ($self,$ID) = @_;
   return '<a href="http://pfam.sanger.ac.uk/family/'.$ID.'">'.$ID.'</a>';
}

sub PubMedLinks{
   my ($self,$ID) = @_;
   return '<a href="http://www.ncbi.nlm.nih.gov/pubmed?term='.substr($ID,7,length($ID)).'">'.substr($ID,7,length($ID)).'</a>';
}

sub MaizeSeqLinks{
	my ($self,$ID) = @_;
	my $db="g";

	if(substr($ID,-4,1) eq "T"){
	$db="t";
	}elsif(substr($ID,-4,1) eq "P"){
	$db="p";
	}

	return '<a href="http://www.maizesequence.org/Zea_mays/Gene?db=core;'.$db.'='.$ID.'" target="_blank">'.$ID.'</a>';
}

sub NCBILinks{
	my ($self,$ID) = @_;
	my $db="protein";

	if(substr($ID,1,1) eq "P"){
	$db="protein";
	}elsif(substr($ID,1,1) eq "M"){
	$db="nuccore";
	}

	return '<a href="http://www.ncbi.nlm.nih.gov/'.$db.'/'.$ID.'" target="_blank">'.$ID.'</a>';
}

sub EntrezGeneLinks {
	my ($self,$ID) = @_;

	return '<a href="http://www.ncbi.nlm.nih.gov/sites/entrez?db=gene&term='.$ID.'" target="_blank">'.$ID.'</a>';
}

sub TAIRGeneLinks {
	my ($self,$ID) =@_;

	return '<a href="http://www.arabidopsis.org/servlets/Search?type=general&search_action=detail&sub_type=gene&name='.$ID.'" target="_blank">'.$ID."</a>";
}

sub KEGGECLinks {
	my ($self,$ID) = @_;

	return '<a href="http://www.genome.jp/dbget-bin/www_bget?enzyme+'.$ID.'" target="_blank">'.$ID."</a>";
}

sub KEGGReactionLinks {
	my ($self,$ID) = @_;

	return '<a href="http://www.genome.jp/dbget-bin/www_bget?rn+'.$ID.'" target="_blank">'.$ID."</a>";
}

sub KEGGCompoundLinks {
	my ($self,$ID) = @_;

	return '<a href="http://www.genome.jp/dbget-bin/www_bget?cpd:'.$ID.'" target="_blank">'.$ID."</a>";
}

=head3 get_growmatch_stats
Definition:
	(FIGMODELTable::GapfillData,FIGMODELTable::GapGenData) = $model->get_growmatch_stats(ArrayRef::GapFillModelList,ArrayRef::GapGenModelList);
Description:
Example:
=cut

sub get_growmatch_stats {
	my ($self,$List,$Type) = @_;

	#Instantiating output data tables
	my $Table = ModelSEED::FIGMODEL::FIGMODELTable->new(["Reaction","Roles","Equation","Number of solutions"],"/home/chenry/".$Type."Compilation.txt",["Reaction"],";","|",undef);

	for (my $i=0; $i < @{$List};$i++) {
		my $ModelID = $List->[$i];
		my $model = $self->get_model($ModelID);
		if (defined($model)) {
			if (-e $model->directory().$ModelID."-".$Type."-FinalSolution.txt") {
				my $SolutionReactions = LoadMultipleColumnFile($model->directory().$ModelID."-".$Type."-FinalSolution.txt",";");
				for (my $j=0; $j <@{$SolutionReactions};$j++) {
					my $ReactionRow = $Table->get_row_by_key($SolutionReactions->[$j]->[0].":".$SolutionReactions->[$j]->[1],"Reaction");
					if (!defined($ReactionRow)) {
						my $ReactionObject = $self->LoadObject($SolutionReactions->[$j]->[0]);
						my $Equation = "";
						my $RoleList = "";
						if (defined($ReactionObject) && defined($ReactionObject->{"DEFINITION"}->[0])) {
							$Equation = $ReactionObject->{"DEFINITION"}->[0];
							my $RoleData = $self->roles_of_reaction($SolutionReactions->[$j]->[0]);
							if (defined($RoleData)) {
							  $RoleList = join("|",@{$RoleData});
							}
						}
						$ReactionRow = {"Reaction" => [$SolutionReactions->[$j]->[0].":".$SolutionReactions->[$j]->[1]],"Roles" => [$RoleList],"Equation" => [$Equation],"Number of solutions" => [0]};
						$Table->add_row($ReactionRow);
					}
					$ReactionRow->{"Number of solutions"}->[0]++;
					$ReactionRow->{$ModelID}->[0] = 1;
					$Table->add_headings(($ModelID));
				}
			} else {
				print STDERR "Could not find gapfill solution file:".$model->directory().$ModelID."-".$Type."-FinalSolution.txt\n";
			}
		}
	}
	$Table->save();
}



=head3 CompileSimulationData
Definition:
	void $model->CompileSimulationData(string array ref::list of models)
Description:
Example:
=cut

sub CompileSimulationData {
	my ($self, $Organism) = @_;

	#Getting model data
	my $ModelName = "Seed".$Organism;
	my $model = $self->get_model($ModelName);
	if (!defined($model)) {
		print STDERR "FIGMODEL:CompileSimulationData:Model ".$ModelName." not found!\n";
		return;
	}
	my $Directory = $model->directory();
	my $OrganismName = $self->GetModelStats($ModelName)->{"Organism name"}->[0];

	#Getting the list of headings and hashheadings
	my $DataTables;
	my $Headings;
	#Loading analysis ready simulation results
	if (-e $Directory."SimulationOutputSeed".$Organism."VNoBiolog.txt") {
		$DataTables->{"Analysis Ready Seed".$Organism} = ModelSEED::FIGMODEL::FIGMODELTable::load_table($Directory."SimulationOutputSeed".$Organism."VNoBiolog.txt","\t",",",2,undef);
		push(@{$Headings},"Analysis Ready Seed".$Organism);
		if (-e $Directory."SimulationOutputSeed".$Organism.".txt") {
			$DataTables->{"Biolog Consistency Analysis Seed".$Organism} = ModelSEED::FIGMODEL::FIGMODELTable::load_table($Directory."SimulationOutputSeed".$Organism.".txt","\t",",",2,undef);
			push(@{$Headings},"Biolog Consistency Analysis Seed".$Organism);
		}
	} elsif (-e $Directory."SimulationOutputSeed".$Organism.".txt") {
		$DataTables->{"Analysis Ready Seed".$Organism} = ModelSEED::FIGMODEL::FIGMODELTable::load_table($Directory."SimulationOutputSeed".$Organism.".txt","\t",",",2,undef);
		push(@{$Headings},"Analysis Ready Seed".$Organism);
	}
	#Loading consistency analysis simulation results
	print $Directory."SimulationOutputOpt".$Organism."VAnnoOpt.txt\n";
	if (-e $Directory."SimulationOutputOpt".$Organism."VAnnoOpt.txt") {
		$DataTables->{"Essentiality Consistency Analysis Seed".$Organism} = ModelSEED::FIGMODEL::FIGMODELTable::load_table($Directory."SimulationOutputOpt".$Organism."VAnnoOpt.txt","\t",",",2,undef);
		$ModelName = "Opt".$Organism;
		print $ModelName."\n";
		push(@{$Headings},"Essentiality Consistency Analysis Seed".$Organism);
	}
	#Loading gap filled simulation results
	if (-e $Directory."SimulationOutput".$ModelName."VGapFilled.txt") {
		$DataTables->{"GapFilled Seed".$Organism} = ModelSEED::FIGMODEL::FIGMODELTable::load_table($Directory."SimulationOutput".$ModelName."VGapFilled.txt","\t",",",2,undef);
		push(@{$Headings},"GapFilled Seed".$Organism);
	}
	#Loading gap gen simulation results
	if (-e $Directory."SimulationOutput".$ModelName."VOptimized.txt") {
		$DataTables->{"Optimized Seed".$Organism} = ModelSEED::FIGMODEL::FIGMODELTable::load_table($Directory."SimulationOutput".$ModelName."VOptimized.txt","\t",",",2,undef);
		push(@{$Headings},"Optimized Seed".$Organism);
	}

	#Creating the output table if it does not already exist
	if (!defined($self->{"CACHE"}->{"SimulationCompilationTable"})) {
		$self->{"CACHE"}->{"SimulationCompilationTable"} = ModelSEED::FIGMODEL::FIGMODELTable->new([$OrganismName." (Seed".$Organism.")",$Headings->[0]],$self->{"database message file directory"}->[0]."SimulationCompilation.tbl",undef, "|", ";",undef);
		#Adding the rows for the accuracy, CN,CP,FP,FN
		$self->{"CACHE"}->{"SimulationCompilationTable"}->add_row({$OrganismName." (Seed".$Organism.")" => ["Accuracy"],$Headings->[0] => [0]});
		$self->{"CACHE"}->{"SimulationCompilationTable"}->add_row({$OrganismName." (Seed".$Organism.")" => ["Biolog Accuracy"],$Headings->[0] => [0]});
		$self->{"CACHE"}->{"SimulationCompilationTable"}->add_row({$OrganismName." (Seed".$Organism.")" => ["Essentiality Accuracy"],$Headings->[0] => [0]});
		$self->{"CACHE"}->{"SimulationCompilationTable"}->add_row({$OrganismName." (Seed".$Organism.")" => ["Correct negative"],$Headings->[0] => [0]});
		$self->{"CACHE"}->{"SimulationCompilationTable"}->add_row({$OrganismName." (Seed".$Organism.")" => ["Correct positive"],$Headings->[0] => [0]});
		$self->{"CACHE"}->{"SimulationCompilationTable"}->add_row({$OrganismName." (Seed".$Organism.")" => ["False negative"],$Headings->[0] => [0]});
		$self->{"CACHE"}->{"SimulationCompilationTable"}->add_row({$OrganismName." (Seed".$Organism.")" => ["False positive"],$Headings->[0] => [0]});
	} else {
		$self->{"CACHE"}->{"SimulationCompilationTable"}->add_headings($OrganismName." (Seed".$Organism.")");
		$self->{"CACHE"}->{"SimulationCompilationTable"}->add_headings($Headings->[0]);
		$self->{"CACHE"}->{"SimulationCompilationTable"}->get_row(0)->{$Headings->[0]}->[0] = 0;
		$self->{"CACHE"}->{"SimulationCompilationTable"}->get_row(1)->{$Headings->[0]}->[0] = 0;
		$self->{"CACHE"}->{"SimulationCompilationTable"}->get_row(2)->{$Headings->[0]}->[0] = 0;
		$self->{"CACHE"}->{"SimulationCompilationTable"}->get_row(3)->{$Headings->[0]}->[0] = 0;
		$self->{"CACHE"}->{"SimulationCompilationTable"}->get_row(4)->{$Headings->[0]}->[0] = 0;
		$self->{"CACHE"}->{"SimulationCompilationTable"}->get_row(5)->{$Headings->[0]}->[0] = 0;
		$self->{"CACHE"}->{"SimulationCompilationTable"}->get_row(6)->{$Headings->[0]}->[0] = 0;
		$self->{"CACHE"}->{"SimulationCompilationTable"}->get_row(0)->{$OrganismName." (Seed".$Organism.")"}->[0] = "Accuracy";
		$self->{"CACHE"}->{"SimulationCompilationTable"}->get_row(1)->{$OrganismName." (Seed".$Organism.")"}->[0] = "Biolog Accuracy";
		$self->{"CACHE"}->{"SimulationCompilationTable"}->get_row(2)->{$OrganismName." (Seed".$Organism.")"}->[0] = "Essentiality Accuracy";
		$self->{"CACHE"}->{"SimulationCompilationTable"}->get_row(3)->{$OrganismName." (Seed".$Organism.")"}->[0] = "Correct negative";
		$self->{"CACHE"}->{"SimulationCompilationTable"}->get_row(4)->{$OrganismName." (Seed".$Organism.")"}->[0] = "Correct positive";
		$self->{"CACHE"}->{"SimulationCompilationTable"}->get_row(5)->{$OrganismName." (Seed".$Organism.")"}->[0] = "False negative";
		$self->{"CACHE"}->{"SimulationCompilationTable"}->get_row(6)->{$OrganismName." (Seed".$Organism.")"}->[0] = "False positive";
	}
	my $FinalTable = $self->{"CACHE"}->{"SimulationCompilationTable"};

	#Adding the data to the simulation compilation table
	my $CurrentIndex = 7;
	foreach my $Heading (@{$Headings}) {
		my $TotalIncorrect = 0;
		my $TotalCorrect = 0;
		my $TotalIncorrectEss = 0;
		my $TotalCorrectEss = 0;
		my $TotalIncorrectBiolog = 0;
		my $TotalCorrectBiolog = 0;
		my $DataTable = $DataTables->{$Heading};
		for (my $i=0; $i < $DataTable->size(); $i++) {
			my $Row = $DataTable->get_row($i);
			my $Key;
			if ($Row->{"Experiment type"}->[0] eq "Media growth") {
				$Key = "Growth in ".$Row->{"Media"}->[0];
			} elsif ($Row->{"Experiment type"}->[0] eq "Gene KO") {
				$Key = $Row->{"Experiment ID"}->[0]." KO in ".$Row->{"Media"}->[0];
			} else {
				$Key = $Row->{"Experiment type"}->[0]."-".$Row->{"Media"}->[0]."-".$Row->{"Experiment ID"}->[0];
			}
			#Dealing with first column
			$FinalTable->add_headings($Heading);
			my $Found = 0;
			for (my $j=7; $j < $CurrentIndex; $j++) {
				if ($FinalTable->get_row($j)->{$OrganismName." (Seed".$Organism.")"}->[0] eq $Key) {
					$Found = 1;
					$FinalTable->get_row($j)->{$Heading} = $Row->{"Run result"};
					last;
				}
			}
			if ($Found == 0) {
				if ($CurrentIndex >= $FinalTable->size()) {
					$FinalTable->add_row({$OrganismName." (Seed".$Organism.")" => [$Key],$Heading => $Row->{"Run result"}});
				} else {
					$FinalTable->get_row($CurrentIndex)->{$OrganismName." (Seed".$Organism.")"}->[0] = $Key;
					$FinalTable->get_row($CurrentIndex)->{$Heading} = $Row->{"Run result"};
				}
				$CurrentIndex++;
			}
			#Counting errors and correct predictions
			if ($Row->{"Run result"}->[0] eq "Correct negative") {
				if ($Row->{"Experiment type"}->[0] eq "Media growth") {
					$TotalCorrectBiolog++;
				} elsif ($Row->{"Experiment type"}->[0] eq "Gene KO") {
					$TotalCorrectEss++;
				}
				$TotalCorrect++;
				$FinalTable->get_row(3)->{$Heading}->[0]++;
			} elsif ($Row->{"Run result"}->[0] eq "False negative") {
				if ($Row->{"Experiment type"}->[0] eq "Media growth") {
					$TotalIncorrectBiolog++;
				} elsif ($Row->{"Experiment type"}->[0] eq "Gene KO") {
					$TotalIncorrectEss++;
				}
				$TotalIncorrect++;
				$FinalTable->get_row(5)->{$Heading}->[0]++;
			} elsif ($Row->{"Run result"}->[0] eq "Correct positive") {
				if ($Row->{"Experiment type"}->[0] eq "Media growth") {
					$TotalCorrectBiolog++;
				} elsif ($Row->{"Experiment type"}->[0] eq "Gene KO") {
					$TotalCorrectEss++;
				}
				$TotalCorrect++;
				$FinalTable->get_row(4)->{$Heading}->[0]++;
			} elsif ($Row->{"Run result"}->[0] eq "False positive") {
				if ($Row->{"Experiment type"}->[0] eq "Media growth") {
					$TotalIncorrectBiolog++;
				} elsif ($Row->{"Experiment type"}->[0] eq "Gene KO") {
					$TotalIncorrectEss++;
				}
				$TotalIncorrect++;
				$FinalTable->get_row(6)->{$Heading}->[0]++;
			}
		}
		#Calculating accuracy
		$FinalTable->get_row(0)->{$Heading}->[0] = $TotalCorrect/($TotalCorrect+$TotalIncorrect);
		if ($TotalCorrectBiolog+$TotalIncorrectBiolog > 0) {
			$FinalTable->get_row(1)->{$Heading}->[0] = $TotalCorrectBiolog/($TotalCorrectBiolog+$TotalIncorrectBiolog);
		}
		if ($TotalCorrectEss+$TotalIncorrectEss > 0) {
			$FinalTable->get_row(2)->{$Heading}->[0] = $TotalCorrectEss/($TotalCorrectEss+$TotalIncorrectEss);
		}
	}
}

=head3 _roles_rxns_in_model
Definition:
	(string array ref::role names,string array ref::reaction IDs) = FIGMODEL->_roles_rxns_in_model(string array ref::list of models)
Description:
Example:
=cut

sub _roles_rxns_in_model {
	my ($self, $org_id, $peg_id, $pegs_to_roles, $roles_to_rxns, $rxns_to_models ) = @_;

	my $roles = [];
	my $reactions = [];

	# For each role
	if( defined( $pegs_to_roles->{$peg_id} ) ){
		foreach my $role ( @{ $pegs_to_roles->{$peg_id} } ){
			my $insert = 0;
			# Return it if any reaction came from an organism we supplied
			if( defined($roles_to_rxns->{$role}) ){
				# And return each reaction that qualifies
				foreach my $rxn ( @{ $roles_to_rxns->{$role}} ){
					foreach( @{$rxns_to_models->{$rxn}} ){
						if( m/$org_id/ ){
							push @$reactions, $rxn;
							$insert = 1;
						}
					}
				}
			}
			push( @$roles, $role ) if $insert;
		}
	}
	return ( $roles, $reactions );
}

sub PrepSkeletonDirectory {
	my ($self, $directory,$genomeid) = @_;
	#Checking that the required input files are present
	if (!-e $directory."Genes.txt") {
		$self->error_message("FIGMODEL:PrepSkeletonDirectory:Required input file: ".$directory."Genes.txt not present!");
		return $self->fail();
	}
	if (!-e $directory.$genomeid.".1.fasta") {
		$self->error_message("FIGMODEL:PrepSkeletonDirectory:Required input file: ".$directory.$genomeid.".1.fasta");
		return $self->fail();
	}
	#Creating the necessary directories
	if (!-d $directory.$genomeid) {
		system("mkdir ".$directory.$genomeid);
	}
	if (!-d $directory.$genomeid."/Features/") {
		system("mkdir ".$directory.$genomeid."/Features/");
	}
	if (!-d $directory.$genomeid."/Features/peg/") {
		system("mkdir ".$directory.$genomeid."/Features/peg/");
	}
	#Opening fasta output file
	open (FASTA, ">".$directory.$genomeid."/Features/peg/fasta");
	#Opening table output file
	open (TABLE, ">".$directory.$genomeid."/Features/peg/tbl");
	#Opening gene file
	open (INPUT, "<".$directory."Genes.txt");
	#Keeping count of the current peg
	my $CurrentPeg = 1;
	while (my $Line = <INPUT>) {
		if ($Line =~ m/^>.+coord=(\d)+:(\d+)\.\.(\d+):([^;]+);/) {
			my $chromosome = $1;
			my $start = $2;
			my $end = $3;
			my $dir = $4;
			if ($dir eq "-1") {
				my $temp = $end;
				$end = $start;
				$start = $temp;
			}
			print FASTA ">fig|".$genomeid.".peg.".$CurrentPeg."\n";
			print TABLE "fig|".$genomeid.".peg.".$CurrentPeg."\t".$genomeid.".".$chromosome."_".$start."_".$end."\n";
			$CurrentPeg++;
		} else {
			print FASTA $Line;
		}
	}
	close(INPUT);
	close(TABLE);
	close(FASTA);
	#Combining the contig files
	open (CONTIG, ">".$directory.$genomeid."/contigs");
	my $contig = 1;
	while (-e $directory.$genomeid.".".$contig.".fasta") {
		#Opening fasta file
		open (INPUT, "<".$directory.$genomeid.".".$contig.".fasta");
		#Clearing the first line
		my $Line = <INPUT>;
		#Writing the correct first line
		print CONTIG ">".$genomeid.".".$contig."\n";
		while ($Line = <INPUT>) {
			print CONTIG $Line;
		}
		close(INPUT);
		$contig++;
	}
	close(CONTIG);
}

=head2 Model Regulation Related Methods

=head3 GetRegulonById
Definition:
	$FIGMODELTableRow = $model->GetRegulonById( $RegulonIdScalar );
Description:
	This function takes a scalar Id for a regulon, e.g. "fig|211586.9.reg.242"
	and returns a reference to a Hash containing the row data.
Example:
		
=cut
sub GetRegulonById {
	my ($self, $regulonId) = @_;
	my $organism;
  	if( $regulonId =~ /fig\|(\d+\.\d+)/ ) { # get 211586.9 out of "fig|211586.9.reg.242"
		$organism = $1;
	} else {
		return undef;
	}
	# Regulons located in file inside "DB ROOT"/TRN-DB/"organism-ID"/Regulons.tbl
	my $regulonTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->{'database root directory'}->[0].'/TRN-DB/'.
													$organism.'/' . "Regulons.tbl", '\t', ',', 0, ['ID']);
	unless(defined($regulonTable)) {
		return undef;
	}
	my $regulon = $regulonTable->get_row_by_key($regulonId, 'ID');
	unless(defined($regulon)) {
		return undef;
	}
	return $regulon;
}
	
=head3 GetEffectorsOfRegulon
Definition:
	$EffectorList = $model->GetEffectorsOfRegulon( $RegulonIdScalar );
Description:
	This function takes a scalar Id for a regulon, e.g. "fig|211586.9.reg.242"
	and returns a reference to an array of effector ID strings
Example:
		
=cut
sub GetEffectorsOfRegulon {
	my ($self, $regulonId) = @_;
	# Get the regulon row
	my $regulon = $self->GetRegulonById($regulonId);
	unless(defined($regulon)) { return undef; }
	# Get the rule ( there can only be one )
	my $rule = $regulon->{'RULE'}->[0];
	unless(defined($rule)) { return undef; }
	my @splitRule = split( /[\s\(\)]/, $rule );
	my $results = [];
	foreach my $effector (@splitRule) {
		unless( $effector eq '' or $effector eq 'AND' or
				$effector eq 'OR' or $effector eq 'NOT' ) {
			push(@{$results}, $effector);
		}
	}
	return $results;
}

=head3 parse_experiment_description
Definition:
	FIGMODELTable:experiment table = FIGMODEL->parse_experiment_description([string]:experiment condition description)
Description:
=cut
sub parse_experiment_description {
	my ($self,$descriptions,$genome) = @_;
	
	my $translation = {
		"gly-glu" => ["cpd11592"],
		"n-acetyl-glucosamine" => ["cpd00122"],
		"sodium_thiosulfate" => ["cpd00268","cpd00971"],
		"dl-lactate" => ["cpd00159","cpd00221"],
		"potassium_phosphate_monobasic" => ["cpd00205","cpd00009"],
		"potassium_phosphate_dibasic" => ["cpd00205","cpd00009"],
		"sodium_selenate" => ["cpd03396","cpd00971"],
		"ferric_citrate" => ["cpd03725"],
		"iron(iii)_oxide" => ["cpd10516"],
		"ferrous_oxide" => ["cpd10515"],
		"ferric_nitrilotriacetate" => ["cpd10516"],
		"ammonium_sulfate" => ["cpd00013","cpd00048"],
		"zinc_sulfate" => ["cpd00034","cpd00048"],
		"iron(ii)_chloride" => ["cpd10515","cpd00099"],
		"na2seo4" => ["cpd03396","cpd00971"],
		"potassium_nitrate" => ["cpd00205","cpd00209"],
		"hepes" => ["NONE"],
		"aqds" => ["NONE"],
		"casamino_acids" => ["cpd00023","cpd00033","cpd00035","cpd00039","cpd00041","cpd00051","cpd00053","cpd00054","cpd00060","cpd00066","cpd00069","cpd00084","cpd00107","cpd00119","cpd00129","cpd00132","cpd00156","cpd00161","cpd00322"],
		"peptone" => ["cpd00023","cpd00033","cpd00035","cpd00039","cpd00041","cpd00051","cpd00053","cpd00054","cpd00060","cpd00065","cpd00066","cpd00069","cpd00084","cpd00107","cpd00119","cpd00129","cpd00132","cpd00156","cpd00161","cpd00322"],
		"yeast_extract" => ["cpd00239","cpd00541","cpd00216","cpd00793","cpd00046","cpd00091","cpd00018","cpd00126","cpd00311","cpd00182","cpd00035","cpd00051","cpd01048","cpd00041","cpd00063","cpd01012","cpd11595","cpd00381","cpd00438","cpd00654","cpd10516","cpd00393","cpd00027","cpd00023","cpd00033","cpd00067","cpd00001","cpd00531","cpd00119","cpd00226","cpd00322","cpd00246","cpd00205","cpd00107","cpd00039","cpd00060","cpd00254","cpd00971","cpd00218","cpd00066","cpd00009","cpd00644","cpd00129","cpd00220","cpd00054","cpd00048","cpd00161","cpd00184","cpd00065","cpd00069","cpd00092","cpd00249","cpd00156","cpd00034","cpd00007","cpd00099","cpd00058","cpd00149","cpd00030","cpd10515","cpd00028"],
		"aluminum_potassium_disulfate" => ["cpd00205","cpd000048"],
		"ammonium_chloride" => ["cpd00013","cpd00099"],
		"b12" => ["cpd00166"],
		"b5" => ["NONE"],
		"biotin(d-biotin)" => ["cpd00104"],
		"boric_acid" => ["cpd09225"],
		"calcium_chloride" => ["cpd00063","cpd00099"],
		"cobalt_chloride" => ["cpd000149","cpd00099"],
		"culture_o2" => ["cpd00007"],
		"cupric_sulfate" => ["cpd00058","cpd00048"],
		"dl-serine" => ["cpd00054","cpd000550"],
		"ferrous_sulfate" => ["cpd10515","cpd00048"],
		"folic_acid" => ["cpd00393"],
		"fumarate" => ["cpd00106"],
		"l-arginine" => ["cpd00051"],
		"l-glutamic_acid" => ["cpd00023"],
		"lactate" => ["cpd00159"],
		"magnesium_sulfate" => ["cpd00254"],
		"manganese_sulfate" => ["cpd00030"],
		"nickel_chloride" => ["cpd00244","cpd00099"],
		"nicotinic_acid" => ["cpd00218"],
		"nitrilotriacetic_acid" => ["NONE"],
		"p-aminobenzoic_acid" => ["cpd00443"],
		"potassium_chloride" => ["cpd00205","cpd00099"],
		"pyridoxine_hcl" => ["cpd00478","cpd00099"],
		"riboflavin" => ["cpd00220"],
		"sodium_chloride" => ["cpd00971","cpd00099"],
		"sodium_molybdate" => ["cpd00971","cpd11574"],
		"sodium_phosphate_monobasic" => ["cpd00971","cpd00009"],
		"sodium_tungstate" => ["cpd00971","cpd15574"],
		"thiamine_hcl" => ["cpd00305","cpd00099"],
		"thioctic_acid" => ["NONE"],
		"zinc_chloride" => ["cpd00034","cpd00099"]
	};
    if(ref($descriptions) eq "ARRAY" && @$descriptions == 1 &&
        -f $descriptions->[0]) {
        $descriptions = $self->database()->load_single_column_file($descriptions->[0]);
    }
	#Processing the input list of experimental conditions
	$self->database()->LockDBTable("EXPERIMENT");
	$self->database()->LockDBTable("MEDIA");
	my $temp = $self->database()->GetDBTable("MEDIA");
	for (my $i=0; $i < $temp->size(); $i++) {
		my @sortedcpd = sort(@{$temp->get_row($i)->{COMPOUNDS}});
		$temp->get_row($i)->{cpdcode}->[0] = join("",@sortedcpd);
	}
	$temp->add_hashheadings(("cpdcode"));
	for (my $i=0; $i < @{$descriptions}; $i++) {
		my @array = split(/\t/,$descriptions->[$i]);
		#Checking if an experiment by the same name already exists
		my $newobj = {_type => "EXPERIMENT",_key => "name",name => [$array[0]],genome => [$genome]};
		my $newmedia = {_type => "MEDIA",_key => "cpdcode",NAME => [$array[0]."_media"]};
		my $columns;
		for (my $k=1; $k < @array; $k++) {
			my @subarray = split(/:/,$array[$k]);
			my $compound;
			#Checking if a translation exists
			if (defined($translation->{$subarray[0]})) {
				for (my $j=0; $j < @{$translation->{$subarray[0]}};$j++) {
					$compound = $self->database()->get_object_from_db("COMPOUNDS",{"DATABASE"=>$translation->{$subarray[0]}->[$j]});
					if (defined($compound)) {
						my $add = 1;
						if (defined($newmedia->{COMPOUNDS})) {
							for (my $m=0; $m < @{$newmedia->{COMPOUNDS}};$m++) {
								if ($newmedia->{COMPOUNDS}->[$m] eq $compound->{DATABASE}->[0]) {
									$add = 0;
								}
							}
						}
						if ($add == 1) {
							push(@{$newmedia->{COMPOUNDS}},$compound->{DATABASE}->[0]);
							push(@{$newmedia->{NAMES}},$compound->{NAME}->[0]);
							push(@{$newmedia->{MAX}},100);
							push(@{$newmedia->{MIN}},-100);
							push(@{$newmedia->{CONCENTRATIONS}},$subarray[1]);
						}
					}
				}
			} else {
				#Checking if the item could refer to a chemical compound
				my @names = $self->convert_to_search_name($subarray[0]);
				for (my $j=0; $j < @names; $j++){
					$compound = $self->database()->get_object_from_db("COMPOUNDS",{"SEARCHNAME"=>$names[$j]});
					if (defined($compound)) {
						last;
					}
				}
				#if this is a compound, we add it to the media, otherwise we add as a column to the experiment table
				if (defined($compound)) {
					my $add = 1;
					if (defined($newmedia->{COMPOUNDS})) {
						for (my $m=0; $m < @{$newmedia->{COMPOUNDS}};$m++) {
							if ($newmedia->{COMPOUNDS}->[$m] eq $compound->{DATABASE}->[0]) {
								$add = 0;
							}
						}
					}
					if ($add == 1) {
						push(@{$newmedia->{COMPOUNDS}},$compound->{DATABASE}->[0]);
						push(@{$newmedia->{NAMES}},$compound->{NAME}->[0]);
						push(@{$newmedia->{MAX}},100);
						push(@{$newmedia->{MIN}},-100);
						push(@{$newmedia->{CONCENTRATIONS}},$subarray[1]);
					}
				} else {
					$newobj->{$subarray[0]}->[0] = $subarray[1];
					$columns->{$subarray[0]} = "";
				}
			}
		}
		if (defined($newmedia->{COMPOUNDS}) && @{$newmedia->{COMPOUNDS}} > 0) {
			my @sortedcpd = sort(@{$newmedia->{COMPOUNDS}});
			$newmedia->{cpdcode}->[0] = join("",@sortedcpd);
			$newmedia = $self->database()->add_object_to_db($newmedia,0);
			$newobj->{media}->[0] = $newmedia->{NAME}->[0];
		}
		$self->database()->add_object_to_db($newobj,1);
		$self->database()->add_columns_to_db("EXPERIMENT",$columns);
	}
	$self->database()->GetDBTable("EXPERIMENT")->save();
	$self->database()->GetDBTable("MEDIA")->save();
	$self->database()->UnlockDBTable("EXPERIMENT");
	$self->database()->UnlockDBTable("MEDIA");
}
=head3 getExperimentsTable
Definition:
	FIGMODELTable:experiment table = FIGMODEL->getExperimentsTable()
Description:
	Returns the experiment table object.
=cut

sub getExperimentsTable {
	my ($self) = @_;
	unless (defined($self->{"CACHE"}->{"EXPERIMENT_TABLE"})) {
		$self->{"CACHE"}->{"EXPERIMENT_TABLE"} = ModelSEED::FIGMODEL::FIGMODELTable::load_table(
			$self->{"Reaction database directory"}->[0]."masterfiles/Experiments.txt",
			'\t', ',', 0, ['name', 'genome']) or die "Could not load Experiments database! Error: " . $!;
	}
	return $self->{"CACHE"}->{"EXPERIMENT_TABLE"};
}

=head3 getExperimentsByGenome
Definition:
	ArrayRef[[string] experimentId]  = FIGMODEL->getExperimentsByGenome([string] genomeId)
Description:
	Returns a reference to an array of experimentId strings. 
	Use getExperimentDetails to get experiment data.
=cut
sub getExperimentsByGenome {
	my ($self, $genomeId) = @_;
	my $experimentsTable = $self->getExperimentsTable();
	my @results = $experimentsTable->get_rows_by_key($genomeId, 'genome');
	my @experimentIds;
	foreach my $result (@results) {
		push(@experimentIds, $result->{'name'});
	}
	return \@experimentIds;
}

=head3 getExperimentDetails
Definition:
   FIGMODELTable::row  = FIGMODEL->getExperimentDetails([string] experimentId)
Description:
	Returns a row (hash ref of key => []) containing details of experiment. 
=cut
sub getExperimentDetails {
	my ($self, $experimentId) = @_;
	my $experimentsTable = $self->getExperimentsTable();
	my $row = $experimentsTable->get_row_by_key($experimentId, 'name');
	unless(defined($row)) { return {}; }
	return $row;
}

=head3 patch_models
Definition:
   FIGMODEL->patch_models([] -or- {} of arguments for patch)
Description:
	Runs a patching function on every model in the database to quickly enact some kind of systematic change.
=cut
sub patch_models {
	my ($self,$list) = @_;
	my $models;
	my $start = 0;
	if (!defined($list->[0])) {
		$models = $self->get_models();
	} elsif ($list->[0] =~ m/^\d+$/) {
		$start = $list->[0];
		$models = $self->get_models();
	} else {
		for (my $i=0; $i < @{$list}; $i++) {
			push(@{$models},$self->get_model($list->[$i]));
		}
	}
	for (my $i=$start; $i < @{$models}; $i++) {
		print "Patching model ".$i." ".$models->[$i]->id()."...";
		$models->[$i]->patch_model();
		print " done.\n";
	}
}

=head3 call_model_function
Definition:
   FIGMODEL->call_model_function(string:function,[string]:model list)
Description:
	Runs the specified function on all specified models.
=cut
sub call_model_function {
	my ($self,$function,$list) = @_;
	my $models;
	my $start = 0;
	if (!defined($list->[0])) {
		$models = $self->get_models();
	} elsif ($list->[0] =~ m/^\d+$/) {
		$start = $list->[0];
		$models = $self->get_models();
	} else {
		for (my $i=0; $i < @{$list}; $i++) {
			push(@{$models},$self->get_model($list->[$i]));
		}
	}
	my @arguments;
	if ($function =~ m/(.+)\((.+)\)/) {
		$function = $1;
		@arguments = split(/,/,$2);
	}
	for (my $i=$start; $i < @{$models}; $i++) {
		print "Calling ".$function." on model ".$i." ".$models->[$i]->id()."...";
		if (@arguments > 0) {
			$models->[$i]->$function(@arguments);
		} else {
			$models->[$i]->$function();
		}
		print " done.\n";
	}
}

=head3 process_strain_data
Definition:
   FIGMODEL->process_strain_data()
Description:
=cut
sub process_strain_data {
	my ($self) = @_;
	my $intTbl = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->config("interval directory")->[0]."IntervalDefinitions.tbl","\t","|",0,["ID"]);
	my $intIDTbl = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->config("interval directory")->[0]."IntervalID.tbl","\t","|",0,["ID"]);
	my $singleStrainTbl = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->config("interval directory")->[0]."SingleIntervalStrains.tbl","\t","|",0,["NAME"]);
	my $multiStrainTbl = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->config("interval directory")->[0]."MultiIntervalStrains.tbl","\t","|",0,["NAME"]);
	my $strainTbl = ModelSEED::FIGMODEL::FIGMODELTable->new(["NAME","POSITION 1","POSITION 2","INTERVAL KO","RESISTANCE","PHENOTYPE","KO PEGS","KO GENE NAMES","KO GENE LOCI"],$self->config("interval directory")->[0]."AllStrains.tbl",["NAME","POSITION 1","POSITION 2","INTERVAL KO","RESISTANCE","KO PEGS","KO GENE NAMES","KO GENE LOCI"],"\t","|",undef);
	my $intervalTbl = ModelSEED::FIGMODEL::FIGMODELTable->new(["NAME","ID","START","END","STRAINS","SIZE","KO PEGS","KO GENE NAMES","KO GENE LOCI"],$self->config("interval directory")->[0]."AllIntervals.tbl",["NAME","ID","STRAINS","KO PEGS","KO GENE NAMES","KO GENE LOCI"],"\t","|",undef);
	my $featureStrainTbl = ModelSEED::FIGMODEL::FIGMODELTable->new(["PEG ID","LOCUS ID","GENE NAME","KO STRAINS","KO INTERVALS","FUNCTION","MIN LOCATION","MAX LOCATION"],$self->config("interval directory")->[0]."AllGenes.tbl",["PEG ID","LOCUS ID","GENE NAME","KO STRAINS","KO INTERVALS","FUNCTION"],"\t","|",undef);
	my $featureTbl = $self->GetGenomeFeatureTable("224308.1");
	for (my $j=0; $j < $featureTbl->size(); $j++) {
		my $featureRow = $featureTbl->get_row($j);
		if ($featureRow->{"ID"}->[0] =~ m/(peg\.\d+)/) {
			my $peg = $1;
			my $newRow = {"PEG ID"=>[$peg],"FUNCTION"=>$featureRow->{"ROLES"},"MIN LOCATION"=>$featureRow->{"MIN LOCATION"},"MAX LOCATION"=>$featureRow->{"MAX LOCATION"}};
			for (my $k=0; $k < @{$featureRow->{ALIASES}}; $k++) {
				if ($featureRow->{ALIASES}->[$k] =~ m/Bsu\d+/) {
					$newRow->{"LOCUS ID"}->[0] = $featureRow->{ALIASES}->[$k];
				} elsif ($featureRow->{ALIASES}->[$k] =~ m/^[A-Za-z]{3,5}$/) {
					$newRow->{"GENE NAME"}->[0] = $featureRow->{ALIASES}->[$k];
				}
			}
			$featureStrainTbl->add_row($newRow);
		}
	}
	for (my $i=0; $i < $intTbl->size(); $i++) {
		my $row = $intTbl->get_row($i);
		my $intRow = $intervalTbl->get_row_by_key($row->{ID}->[0],"NAME",1);
		$intRow->{"END"}->[0] = $row->{"END"}->[0];
		$intRow->{START}->[0] = $row->{START}->[0];
		$intRow->{SIZE}->[0] = $row->{"END"}->[0] - $intRow->{START}->[0];
		for (my $j=0; $j < $featureTbl->size(); $j++) {
			my $featureRow = $featureTbl->get_row($j);
			if ($featureRow->{"ID"}->[0] =~ m/(peg\.\d+)/ && $featureRow->{"MAX LOCATION"}->[0] > $intRow->{START}->[0] && $featureRow->{"MIN LOCATION"}->[0] < $intRow->{"END"}->[0]) {
				my $peg = $1;
				my $featureStrainRow = $featureStrainTbl->get_row_by_key($peg,"PEG ID");
				if (defined($featureStrainRow)) {
					push(@{$featureStrainRow->{"KO INTERVALS"}},$row->{ID}->[0]);	
				}
				push(@{$intRow->{"KO PEGS"}},$peg);
				my $name = $peg;
				my $locus = $peg;
				for (my $k=0; $k < @{$featureRow->{ALIASES}}; $k++) {
					if ($featureRow->{ALIASES}->[$k] =~ m/Bsu\d+/) {
						$locus = $featureRow->{ALIASES}->[$k];
					} elsif ($featureRow->{ALIASES}->[$k] =~ m/^[A-Za-z]{3,5}$/) {
						$name = $featureRow->{ALIASES}->[$k];
					}
				}
				push(@{$intRow->{"KO GENE NAMES"}},$name);
				push(@{$intRow->{"KO GENE LOCI"}},$locus);
			}
		}
	}
	for (my $i=0; $i < $intIDTbl->size(); $i++) {
		my $row = $intIDTbl->get_row($i);
		for (my $j=0; $j < @{$row->{INTERVALS}};$j++) {
			my $intRow = $intervalTbl->get_row_by_key($row->{INTERVALS}->[$j],"NAME",1);
			$intervalTbl->add_data($intRow,"ID",$row->{ID}->[0],1);
		}
	}
	$intervalTbl->save();
	for (my $i=0; $i < $singleStrainTbl->size(); $i++) {
		my $row = $singleStrainTbl->get_row($i);
		my $strainRow = $strainTbl->get_row_by_key($row->{NAME}->[0],"NAME",1);
		$strainRow->{"POSITION 1"}->[0] = $row->{"POSITION 1"}->[0];
		$strainRow->{"POSITION 2"}->[0] = $row->{"POSITION 2"}->[0];
		$strainRow->{"INTERVAL KO"} = $row->{INTERVALS};
		$strainRow->{"RESISTANCE"} = $row->{RESISTANCE};
		if ($row->{NMS}->[0] eq "+") {
			$strainRow->{"PHENOTYPE"}->[0] = "Growth on NMS";
		} elsif ($row->{NMS}->[0] eq "Slow") {
			$strainRow->{"PHENOTYPE"}->[0] = "Slow on NMS";
		} elsif ($row->{NMS}->[0] eq "-" && $row->{LB}->[0] eq "+") {
			$strainRow->{"PHENOTYPE"}->[0] = "Growth on LB";
		} elsif ($row->{NMS}->[0] eq "-" && $row->{LB}->[0] eq "Slow") {
			$strainRow->{"PHENOTYPE"}->[0] = "Slow on LB";
		} else {
			$strainRow->{"PHENOTYPE"}->[0] = "No growth";
		}
		for (my $j=0; $j < @{$strainRow->{"INTERVAL KO"}}; $j++) {
			my $intRow = $intervalTbl->get_row_by_key($strainRow->{"INTERVAL KO"}->[$j],"NAME");
			if (defined($intRow)) {
				push(@{$intRow->{STRAINS}},$row->{NAME}->[0]);
				push(@{$strainRow->{"KO PEGS"}},@{$intRow->{"KO PEGS"}});
				push(@{$strainRow->{"KO GENE NAMES"}},@{$intRow->{"KO GENE NAMES"}});
				push(@{$strainRow->{"KO GENE LOCI"}},@{$intRow->{"KO GENE LOCI"}});
			}
		}
	}
	for (my $i=0; $i < $multiStrainTbl->size(); $i++) {
		my $row = $multiStrainTbl->get_row($i);
		my $strainRow = $strainTbl->get_row_by_key($row->{NAME}->[0],"NAME",1);
		$strainRow->{"POSITION 1"}->[0] = $row->{"POSITION 1"}->[0];
		$strainRow->{"POSITION 2"}->[0] = $row->{"POSITION 2"}->[0];
		for (my $j=0; $j < @{$row->{INTERVALS}}; $j++) {
			my @rows = $intervalTbl->get_rows_by_key($row->{INTERVALS}->[$j],"ID");
			if (@rows == 0) {
				print $row->{INTERVALS}->[$j]." has no intervals!\n";
			}
			for (my $k=0; $k < @rows; $k++) {
				push(@{$strainRow->{"INTERVAL KO"}},$rows[$k]->{NAME}->[0]);
			}
		}
		$strainRow->{RESISTANCE} = $row->{RESISTANCE};
		$strainRow->{PHENOTYPE} = $row->{PHENOTYPE};
		if (defined($strainRow->{"INTERVAL KO"})) {
			for (my $j=0; $j < @{$strainRow->{"INTERVAL KO"}}; $j++) {
				my $intRow = $intervalTbl->get_row_by_key($strainRow->{"INTERVAL KO"}->[$j],"NAME");
				if (defined($intRow)) {
					push(@{$intRow->{STRAINS}},$row->{NAME}->[0]);
					push(@{$strainRow->{"KO PEGS"}},@{$intRow->{"KO PEGS"}});
					push(@{$strainRow->{"KO GENE NAMES"}},@{$intRow->{"KO GENE NAMES"}});
					push(@{$strainRow->{"KO GENE LOCI"}},@{$intRow->{"KO GENE LOCI"}});
				}
			}
		}
	}
	for (my $i=0; $i < $strainTbl->size(); $i++) {
		my $row = $strainTbl->get_row($i);
		if (defined($row->{"KO PEGS"})) {
			for (my $j=0; $j < @{$row->{"KO PEGS"}}; $j++) {
				my $featureStrainRow = $featureStrainTbl->get_row_by_key($row->{"KO PEGS"}->[$j],"PEG ID");
				if (defined($featureStrainRow)) {
					push(@{$featureStrainRow->{"KO STRAINS"}},$row->{NAME}->[0]);
				}
			}
		}
	}
	$strainTbl->save();
	$intervalTbl->save();
	$featureStrainTbl->save();
}

=head2 Utility methods

=head3 processIDList
Definition:
	[string] = FIGMODEL->processIDList({
		objectType => string,
		delimiter => ",",
		column => "id",
		parameters => {},
		input => string
	});
Description:	
=cut
sub processIDList {
	my ($self,$args) = @_;
	$args = $self->process_arguments($args,["objectType","input"],{
		delimiter => ",",
		parameters => {},
		column => "id"
	});
	if ($args->{input} =~ m/\.lst$/) {
		if ($args->{input} =~ m/^\// && -e $args->{input}) {	
			return $self->database()->load_single_column_file($args->{input},"");
		} elsif (-e $self->ws()->directory().$args->{input}) {
			return $self->database()->load_single_column_file($self->ws()->directory().$args->{input},"");
		}
		ModelSEED::globals::ERROR("Cannot obtain ppo data for reaction");
	} elsif ($args->{input} eq "ALL") {
		my $objects = $self->database()->get_objects($args->{objectType},$args->{parameters});
		my $function = $args->{column};
		my $results;
		for (my $i=0; $i < @{$objects}; $i++) {
			if (defined($objects->[$i]->$function())) {
				push(@{$results},$objects->[$i]->$function());	
			}
		}
		return $results;
	} else {
		return [split($args->{delimiter},$args->{input})];
	}
	ModelSEED::globals::ERROR("Unhandled use case");
}

=head3 put_two_column_array_in_hash
Definition:
	({string:1 => string:2},{string:2 => string:1}) = FIGMODEL->put_two_column_array_in_hash([[string:1,string:2]]);
Description:
	Loads the input array into a hash
=cut
sub put_two_column_array_in_hash {
	my ($self,$ArrayRef) = @_;
	if (!defined($ArrayRef) || ref($ArrayRef) ne "ARRAY") {
		return undef;
	}
	my $HashRefOne;
	my $HashRefTwo;
	for (my $i=0; $i < @{$ArrayRef}; $i++) {
		if (ref($ArrayRef->[$i]) eq "ARRAY" && @{$ArrayRef->[$i]} >= 2) {
			$HashRefOne->{$ArrayRef->[$i]->[0]} = $ArrayRef->[$i]->[1];
			$HashRefTwo->{$ArrayRef->[$i]->[1]} = $ArrayRef->[$i]->[0];
		}
	}
	return ($HashRefOne,$HashRefTwo);
}

=head3 put_hash_in_two_column_array
Definition:
	[[string:1,string:2]]/[[string:2,string:1]] = FIGMODEL->put_hash_in_two_column_array({string:1 => string:2},0/1);
Description:
	Loads a hash into a two column array
=cut
sub put_hash_in_two_column_array {
	my ($self,$Hash,$Forward) = @_;
	if (!defined($Hash) || ref($Hash) ne "HASH") {
		return undef;
	}
	my $ArrayRef;
	my @keyArray = keys(%{$Hash});
	for (my $i=0; $i < @keyArray; $i++) {
		if (!defined($Forward) || $Forward == 1) {
			$ArrayRef->[$i]->[0] = $keyArray[$i];
			$ArrayRef->[$i]->[1] = $Hash->{$keyArray[$i]};
		} else {
			$ArrayRef->[$i]->[1] = $keyArray[$i];
			$ArrayRef->[$i]->[0] = $Hash->{$keyArray[$i]};
		}
	}
	return $ArrayRef;
}

=head3 put_array_in_hash
Definition:
	{string => int} = FIGMODEL->put_array_in_hash([string]);
Description:
	Loads the input array into a hash
=cut
sub put_array_in_hash {
	my ($self,$ArrayRef) = @_;
	my $HashRef;
	for (my $i=0; $i < @{$ArrayRef}; $i++) {
		$HashRef->{$ArrayRef->[$i]} = $i;
	}
	return $HashRef;
}

=head3 date
Definition:
	string = FIGMODEL->date(string::time);
Description:
	Translates epoch seconds into a date.
=cut
sub date {
	my ($self,$Time) = @_;
	if (!defined($Time)) {
		$Time = time();
	}
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($Time);

	return ($mon+1)."/".($mday)."/".($year+1900);
}

=head3 runexecutable
Definition:
	[string]:lines of output = FIGMODEL->runexecutable(string:command);
=cut
sub runexecutable {
	my ($self,$Command) = @_;
	my $OutputArray;
	push(@{$OutputArray},`$Command`);
	return $OutputArray;
}

=head3 invert_hash
Definition:
	{string:value B => [string:value A]}:inverted hash = FIGMODEL->invert_hash({string:value A => [string:value B]});
Description:
	Switches the values into keys and the keys into values.
=cut
sub invert_hash {
	my ($self,$inputhash) = @_;
	my $outputhash;
	foreach my $key (keys(%{$inputhash})) {
		foreach my $value (@{$inputhash->{$key}}) {
			push(@{$outputhash->{$value}},$key);
		}
	}
	return $outputhash;
}

=head3 add_elements_unique
Definition:
	([string]::altered array,integer::number of matches) = FIGMODEL->add_elements_unique([string]::existing array,(string)::new elements);
Description:
	Loads the input array into a hash
=cut
sub add_elements_unique {
	my ($self,$ArrayRef,@NewElements) = @_;

	my $ArrayValueHash;
	my $NewArray;
	if (defined($ArrayRef) && @{$ArrayRef} > 0) {
		for (my $i=0; $i < @$ArrayRef; $i++) {
			if (!defined($ArrayValueHash->{$ArrayRef->[$i]})) {
				push(@{$NewArray},$ArrayRef->[$i]);
				$ArrayValueHash->{$ArrayRef->[$i]} = @{$NewArray}-1;
			}
		}
	}

	my $NumberOfMatches = 0;
	for (my $i=0; $i < @NewElements; $i++) {
		if (length($NewElements[$i]) > 0 && !defined($ArrayValueHash->{$NewElements[$i]})) {
			push(@{$NewArray},$NewElements[$i]);
			$ArrayValueHash->{$NewElements[$i]} = @{$NewArray}-1;
		} else {
			$NumberOfMatches++;
		}
	}

	return ($NewArray,$NumberOfMatches);
}

=head3 remove_duplicates
Definition:
	(string)::output array = FIGMODEL->remove_duplicates((string)::input array);
Description:
	Loads the input array into a hash
=cut
sub remove_duplicates {
	my ($self,@OriginalArray) = @_;

	my %Hash;
	my @newArray;
	foreach my $Element (@OriginalArray) {
		if (!defined($Hash{$Element})) {
			$Hash{$Element} = 1;
			push(@newArray,$Element);
		}
	}
	return @newArray;
}

=head3 convert_number_for_viewing
Definition:
	double:converted number = FIGMODEL->convert_number_for_viewing(double:input number);
Description:
	Converts the input number into scientific notation and rounds to the second digit
=cut

sub convert_number_for_viewing {
	my ($self,$input) = @_;
	my $sign = 1;
	if ($input < 0) {
		$sign = -1;
		$input = -1*$input;
	}
	my ($one,$two) = split(/\./,$input);
	my $numDig = 0;
	if ($one > 999) {
		$numDig = length($one)-1;
		my $divisor = 10**$numDig;
		$one = $one/$divisor;
		$input = $one.$two;
	} elsif ($input =~ m/^0\.(0+)/) {
		$numDig = (length($1)+1);
		my $divisor = 10**$numDig;
		$input = $input*$divisor;
		$numDig = -1*$numDig;
	}
	#Rounding number as needed
	$input = sprintf("%.3f", $input);
	#Adding exponent to number if necessary
	$input = $input*$sign;
	if ($numDig != 0) {
		$input .= "e".$numDig;
	}
	return $input;
}

=head3 format_coefficient
Definition:
	string = FIGMODEL->format_coefficient(string);
Description:
	Loads the input array into a hash
=cut
sub format_coefficient {
	my ($self,$Original) = @_;

	#Converting scientific notation to normal notation
	if ($Original =~ m/[eE]/) {
		my $Coefficient = "";
		my @Temp = split(/[eE]/,$Original);
		my @TempTwo = split(/\./,$Temp[0]);
		if ($Temp[1] > 0) {
			my $Index = $Temp[1];
			if (defined($TempTwo[1]) && $TempTwo[1] != 0) {
				$Index = $Index - length($TempTwo[1]);
				if ($Index < 0) {
					$TempTwo[1] = substr($TempTwo[1],0,(-$Index)).".".substr($TempTwo[1],(-$Index))
				}
			}
			for (my $j=0; $j < $Index; $j++) {
				$Coefficient .= "0";
			}
			if ($TempTwo[0] == 0) {
				$TempTwo[0] = "";
			}
			if (defined($TempTwo[1])) {
				$Coefficient = $TempTwo[0].$TempTwo[1].$Coefficient;
			} else {
				$Coefficient = $TempTwo[0].$Coefficient;
			}
		} elsif ($Temp[1] < 0) {
			my $Index = -$Temp[1];
			$Index = $Index - length($TempTwo[0]);
			if ($Index < 0) {
				$TempTwo[0] = substr($TempTwo[0],0,(-$Index)).".".substr($TempTwo[0],(-$Index))
			}
			if ($Index > 0) {
				$Coefficient = "0.";
			}
			for (my $j=0; $j < $Index; $j++) {
				$Coefficient .= "0";
			}
			$Coefficient .= $TempTwo[0];
			if (defined($TempTwo[1])) {
				$Coefficient .= $TempTwo[1];
			}
		}
		$Original = $Coefficient;
	}
	#Removing trailing zeros
	if ($Original =~ m/(.+\..+)0+$/) {
		$Original = $1;
	}
	$Original =~ s/\.0$//;

	return $Original;
}

sub ceil {
	return int(shift()+.5);
}

sub floor {
	return int(shift());
}

=head3 compareArrays
Definition:
	Output = FIGMODEL->compareArrays({
		string:labels => [string]:labels,
		string:data => [[string]]:data
	});
	Output = {
		string:label one => {
			string:label two => double:fraction overlap
		}
	}
Description:
=cut
sub compareArrays {
	my ($self,$args) = @_;
	$args = $self->process_arguments($args,["labels","data"],{type => "fraction"});
	if (defined($args->{error})) {return $self->new_error_message({function => "compareArrays",args => $args});}
	my $results;
	for (my $i=0; $i < @{$args->{labels}}; $i++) {
		for (my $j=0; $j < @{$args->{labels}}; $j++) {
			if ($i == $j) {
				if ($args->{type} eq "decimal") {
					$results->{$args->{labels}->[$i]}->{$args->{labels}->[$j]} = 1;
				} elsif ($args->{type} eq "difference") {
					$results->{$args->{labels}->[$i]}->{$args->{labels}->[$j]} = 0;
				} elsif ($args->{type} eq "fraction") {
					$results->{$args->{labels}->[$i]}->{$args->{labels}->[$j]} = @{$args->{data}->[$i]}."/".@{$args->{data}->[$i]};
				}
			} else {
				my $matchCount = 0;
				for (my $k=0; $k < @{$args->{data}->[$i]}; $k++) {
					for (my $m=0; $m < @{$args->{data}->[$j]}; $m++) {
						if ($args->{data}->[$i]->[$k] eq $args->{data}->[$i]->[$m]) {
							$matchCount++;
							last;
						}
					}
				}
				if ($args->{type} eq "decimal") {
					$results->{$args->{labels}->[$i]}->{$args->{labels}->[$j]} = $matchCount/@{$args->{data}->[$i]};
				} elsif ($args->{type} eq "difference") {
					$results->{$args->{labels}->[$i]}->{$args->{labels}->[$j]} = (@{$args->{data}->[$i]}-$matchCount);
				} elsif ($args->{type} eq "fraction") {
					$results->{$args->{labels}->[$i]}->{$args->{labels}->[$j]} = $matchCount."/".@{$args->{data}->[$i]};
				}
			}
		}	
	}
	return $results;
}

=head3 copyMergeHash
Definition:
	{} = FIGMODEL->copyMergeHash([{}]);
Description:
=cut
sub copyMergeHash {
	my ($self,$hashArray) = @_;
	my $result;
	for (my $i=0; $i < @{$hashArray}; $i++) {
		foreach my $key (keys(%{$hashArray->[$i]})) {
			$result->{$key} = $hashArray->[$i]->{$key};
		}	
	}
	return $result;
}

=head3 make_xls
Definition:
	{} = FIGMODEL->make_xls();
Description:
=cut
sub make_xls {
    my ($self,$args) = @_;
	$args = $self->process_arguments($args,["filename","sheetnames","sheetdata"],{});
    my $workbook = $args->{filename};
    for(my $i=0; $i<@{$args->{sheetdata}}; $i++) {
        $workbook = $args->{sheetdata}->[$i]->add_as_sheet($args->{sheetnames}->[$i],$workbook);
    }
    $workbook->close();
    return;
}

=head2 Pass-through functions that will soon be deleted entirely
=cut
sub CreateSingleGenomeReactionList {
	my ($self,$GenomeID,$Owner,$RunGapFilling) = @_;
	$self->create_model({genome => $GenomeID,owner => $Owner,gapfilling => $RunGapFilling})
}
sub CpdLinks {
	my ($self,$CpdID,$SelectedModel,$Label) = @_;
	$self->web()->CpdLinks($CpdID,$Label);
}
=head3 GetReactionSubstrateData
MOVED TO FIGMODELreaction:MARKED FOR DELETION
=cut
sub GetReactionSubstrateData {
	my ($self,$ReactionID) = @_;
	return $self->get_reaction($ReactionID)->substrates_from_equation();
}
=head3 GetReactionSubstrateDataFromEquation
MOVED TO FIGMODELreaction:MARKED FOR DELETION
=cut
sub GetReactionSubstrateDataFromEquation {
	my ($self,$Equation) = @_;
	return $self->get_reaction("rxn00001")->substrates_from_equation({equation=>$Equation});
}
=head3 LoadProblemReport
IMPLEMENTED IN FIGMODELfba:MARKED FOR DELETION
=cut
sub LoadProblemReport {
	my ($self,$Filename) = @_;
	my $fba = $self->fba({filename=>$Filename});
	return $fba->loadProblemReport();
}
=head3 convert_to_search_name
IMPLEMENTED IN FIGMODELcompound:MARKED FOR DELETION
=cut
sub convert_to_search_name {
	my ($self,$InName) = @_;
	return $self->get_compound("cpd00001")->convert_to_search_name($InName);
}
=head2 Functions that should eventually be in FIGMODELcompound
=cut
sub UpdateCompoundNamesInDB {
	my ($self) = @_;
	my $objs = $self->database()->get_objects("compound");
	for (my $i=0; $i < @{$objs}; $i++) {
		#Getting aliases for compound
		my $als = $self->database()->get_objects("cpdals",{type => "name",COMPOUND => $objs->[$i]->id()});
		my $shortName = "";
		for (my $i=0; $i < @{$als}; $i++) {
			if (length($shortName) == 0 || length($shortName) > length($als->[$i]->alias())) {
				$shortName = $als->[$i]->alias();	
			}
		}
		if (length($shortName) > 0) {
			$objs->[$i]->name($shortName);
		}
	}
}
=head3 set_cache
REPLACED BY FIGMODEL->setCache(...):MARKED FOR DELETION
=cut
sub set_cache {
	my($self,$key,$data) = @_;
	$self->setCache({id=>$self->user(),key => $key,data => $data,package=>"FIGMODEL"});
	return undef;
}
=head3 cache
REPLACED BY FIGMODEL->getCache(...):MARKED FOR DELETION
=cut
sub cache {
	my($self,$key) = @_;
	return $self->getCache({key => $key,package=>"FIGMODEL",id=>$self->user()});
}
=head3 ConvertEquationToCode
IMPLEMENTED IN FIGMODELreaction:MARKED FOR DELETION
=cut
sub ConvertEquationToCode {
	my ($self,$OriginalEquation,$CompoundHashRef) = @_;
	my $rxnObj = $self->get_reaction("rxn00001");
	my $output = $rxnObj->createReactionCode({equation => $OriginalEquation,translations => $CompoundHashRef});
	return ($output->{direction},$output->{code},$output->{reverseCode},$output->{fullEquation},$output->{compartment},$output->{error});
}
=head3 GetGenomeFeatureTable
IMPLEMENTED IN FIGMODELgenome:MARKED FOR DELETION
=cut
sub GetGenomeFeatureTable {
	my($self,$OrganismID,$GetSequences) = @_;
	return $self->get_genome($OrganismID)->feature_table($GetSequences);
}
=head3 roles_of_function
IMPLEMENTED IN FIGMODELrole:MARKED FOR DELETION
=cut
sub roles_of_function {
	my ($self,$Function) = @_;
	return @{$self->get_role()->roles_of_function({function => $Function,output => "name"})};
}
=head3 convert_to_search_role
IMPLEMENTED IN FIGMODELrole:MARKED FOR DELETION
=cut
sub convert_to_search_role {
	my ($self,$inRole) = @_;
	return $self->get_role()->convert_to_search_role({name => $inRole});
}

=head3 subsystems_of_role
IMPLEMENTED IN FIGMODELrole:MARKED FOR DELETION
=cut
sub subsystems_of_role {
	my ($self,$Role) = @_;
	my $rl = $self->get_role($Role);
	if (!defined($rl)) {
		return [];	
	}
	return $rl->subsystems_of_role();
}
=head3 role_is_valid
IMPLEMENTED IN FIGMODELrole:MARKED FOR DELETION
=cut
sub role_is_valid {
	my ($self,$Role) = @_;
	return $self->get_role()->role_is_valid({name => $Role});
}

1;

