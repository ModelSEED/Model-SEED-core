#!/usr/bin/perl -w

########################################################################
# Driver module that holds all functions that govern user interaction with the Model SEED
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 9/6/2011
########################################################################

use strict;
use ModelSEED::FIGMODEL;
use ModelSEED::FIGMODEL::FIGMODELTable;
use ModelSEED::ServerBackends::FBAMODEL;
use Getopt::Long qw(GetOptionsFromArray);
use YAML;
use YAML::Dumper;

package ModelSEED::ModelDriver;

=head3 new
Definition:
	driver = driver->new();
Description:
	Returns a driver object
=cut
sub new { 
	my $self = {_finishedfile => "NONE"};
	ModelSEED::globals::CREATEFIGMODEL();
	ModelSEED::Interface::interface::CREATEWORKSPACE({});
    return bless $self;
}
=head3 figmodel
Definition:
	FIGMODEL = driver->figmodel();
Description:
	Returns a FIGMODEL object
=cut
sub figmodel {
	my ($self) = @_;
	return ModelSEED::globals::GETFIGMODEL();
}
=head3 ws
Definition:
	FIGMODEL = driver->ws();
Description:
	Returns a workspace object
=cut
sub ws {
	my ($self) = @_;
	return ModelSEED::Interface::interface::WORKSPACE();
}
=head3 db
Definition:
	FIGMODEL = driver->db();
Description:
	Returns a database object
=cut
sub db {
	my ($self) = @_;
	return$self->figmodel()->database();
}
=head3 config
Definition:
	{}/[] = driver->config(string);
Description:
	Returns a requested configuration object
=cut
sub config {
	my ($self,$key) = @_;
	return ModelSEED::globals::GETFIGMODEL()->config($key);
}
=head3 check
Definition:
	FIGMODEL = driver->check([string]:expected data,(string):supplied arguments);
Description:
	Check for sufficient arguments
=cut
sub check {
	my ($self,$array,$data) = @_;
	my @calldata = caller(1);
	my @temp = split(/:/,$calldata[3]);
    my $function = pop(@temp);
	if (!defined($data) || @{$data} == 0 || ($data->[0] eq $function && ref($data->[1]) eq "HASH" && keys(%{$data->[1]}) == 0)) {
		print $self->usage($function,$array);
		$self->finish("USAGE PRINTED");
	}
	my $args;
	if (defined($data->[1]) && ref($data->[1]) eq 'HASH') {
		$args = $data->[1];
		delete $data->[1];
	}
	if (defined($args->{"usage"}) || defined($args->{"help"}) || defined($args->{"man"})) {
		print STDERR $self->usage($function,$array);
	}
	for (my $i=0; $i < @{$array}; $i++) {
		if (!defined($args->{$array->[$i]->[0]})) {
			if ($array->[$i]->[1] == 1 && (!defined($data->[$i+1]) || length($data->[$i+1]) == 0)) {
				my $message = "Mandatory argument '".$array->[$i]->[0]."' missing!\n";
				$message .= $self->usage($function,$array);
				print STDERR $message;
				$self->finish($message);
			} elsif ($array->[$i]->[1] == 0 && (!defined($data->[$i+1]) || length($data->[$i+1]) == 0)) {
				$data->[$i+1] = $array->[$i]->[2];
			}
			$args->{$array->[$i]->[0]} = $data->[$i+1];
		}
	}
	return $args;
}
=head3 usage
Definition:
	FIGMODEL = driver->usage(string:function name,[string]:expected data);
Description:
	Prints the usage for the specified function
=cut
sub usage {
	my ($self,$function,$array) = @_;
	if (!defined($array)) {
		$self->$function();
		return undef;
	}
	my $output;
	if ($self->isCommandLineFunction($function) == 0) {
		$output = $function." is not a valid ModelSEED function!\n";
	} else {
		$output = $function." function usage:\n./".$function." ";
	 	for (my $i=0; $i < @{$array}; $i++) {
			if ($i > 0) {
				$output .= "?";
			}
			$output .= $array->[$i]->[0];
			if ($array->[$i]->[1] == 0) {
				if (!defined($array->[$i]->[2])) {
					$output .= "(undef)";
				} else {
					$output .= "(".$array->[$i]->[2].")";
				}
	 		}
	 	}
	 	$output .= "\n";
	}
	return $output;
}
=head3 finishfile
Definition:
	string = driver->finishfile(string:input filename);
Description:
	Getter setter for finish file
=cut
sub finishfile {
	my ($self,$input) = @_;
	if (defined($input)) {
		$self->{_finishedfile} = $input;
	}
	if (!defined($self->{_finishedfile})) {
		$self->{_finishedfile} = "NONE";	
	}
	return $self->{_finishedfile};
}
=head3 isCommandLineFunction
Definition:
	string = driver->isCommandLineFunction(string:input filename);
Description:
	Returns "1" if the input function is a ModelSEED interface function. Returns 0 otherwise.
=cut
sub isCommandLineFunction {
	my ($self,$infunction) = @_;
	if ($self->can($infunction)) {
		my $excluded = {
			finish=>1,outputdirectory=>1,makeArgumentHashFromCommand=>1,"new"=>1,finishfile=>1,usage=>1,check=>1,config=>1,db=>1,ws=>1,figmodel=>1
		};
		if (defined($excluded->{$infunction})) {
			return 0;
		}
		return 1;
	}
	return 0;
}
=head3 finish
Definition:
	FIGMODEL = driver->finish(string:message);
Description:
	Closes out the ModelDriver with the specified message
=cut
sub finish {
	my ($self,$message) = @_;
	if ($self->finishfile() ne "NONE") {
	    if ($self->{_finishedfile} =~ m/^\//) {
	        ModelSEED::utilities::PRINTFILE($self->finishfile(),[$message]);
	    } else {
	        ModelSEED::utilities::PRINTFILE($self->figmodel()->config("database message file directory")->[0].$self->finishfile(),[$message]);
	    }
	}
	exit();
}
=head3 outputdirectory
Definition:
	FIGMODEL = driver->outputdirectory();
Description:
	Returns the directory where output should be printed
=cut
sub outputdirectory {
	my ($self) = @_;
	return $self->{_outputdirectory};
}

sub makeArgumentHashFromCommand {
    my ($self, @Data);
    my $error = <<XATNYS;
Advanced command syntax:
    ProdModelDriver.sh normal?arguments?-flag?-flagWith=Value?more?normal?args
    Basically, ?-flag? for a boolean flag, ?-flag=Value? for a key -> value pair.
    Returns (hash, arrayRef) where hash is a hash of key -> value and key -> '1' for flags.
    And arrayRef is all remaining normal arguments
XATNYS
    my $args = {};
    my $otherArgs = [];
    for(my $i=0; $i< scalar(@Data); $i++) {
        if($Data[$i] =~ m/^-(.+)=(.+)/) {
            my $key = $1;
            my $value = $2;
            if(length($key) > 0 && length($value) > 0) {
                $args->{$key} = $value; 
                next;
            }
        }
        if($Data[$i] =~ m/^-(.+)/) {
            my $key = $1;
            if(length($key) > 0) {
                $args->{$key} = 1;
                next;
            }
        }
        push(@$otherArgs, $Data[$i]); # Push onto other arguments if we didn't find a flagged one
    }
    return ($args, $otherArgs);
}
            

=head
=CATEGORY
Database Operations
=DESCRIPTION
This function lists all objects matching the input type and query
=EXAMPLE
./db-listobjects
=cut
sub dblistobjects {
    my ($self, @Data) = @_;
    my $args = $self->check([
		["type",1,undef,"Type of object to be listed"],
		["query",0,undef,"A '|' delimited list of queries described as 'field=A'"],
		["sudo",0,0,"Set to '1' to list all objects in database regardless of rights"]
	],[@Data],"blast sequences against genomes");
    my $query = {};
    if (defined($args->{query})) {
    	my $queries = [split(/\|/,$args->{query})];
    	for (my $i=0; $i < @{$queries}; $i++) {
    		my $array = [split(/\=/,$queries->[$i])];
    		if (defined($array->[1])) {
    			$query->{$array->[0]} = $array->[1];
    		}
    	}
    }
    my $objs;
    if ($args->{sudo} == 1) {
    	$objs = $self->db()->sudo_get_objects($args->{type},$query);
    } else {
    	$objs = $self->db()->get_objects($args->{type},$query);
    }
    if (!defined($objs) || !defined($objs->[0])) {
    	return "No objects found matching input type and query!";
    }
    my $attributes = [keys(%{$objs->[0]->attributes()})];
    my $output = [join("\t",@{$attributes})];
    for (my $i=0; $i < @{$objs}; $i++) {
    	my $line;
    	for (my $j=0; $j < @{$attributes}; $j++) {
    		if ($j > 0) {
    			$line .= "\t";	
    		}
    		my $function = $attributes->[$j];
    		$line .= $objs->[$i]->$function();
    	}
    	push(@{$output},$line);
    }
    my $num = @{$objs};
    ModelSEED::utilities::PRINTFILE($self->ws()->directory()."Query-".$args->{type}.".tbl",$output);
    return "Successfully printed ".$num." objects to file ".$self->ws()->directory()."Query-".$args->{type}.".tbl";
}
=head
=CATEGORY
Database Operations
=DESCRIPTION
This function creates a new object defined in the specified file in the database 
=EXAMPLE
./db-createobject
=cut
sub dbcreateobject {
    my ($self, @Data) = @_;
    my $args = $self->check([
		["filename",1,undef,"Name of file containing object data"],
	],[@Data],"create new object in the database");
    if (!-e $self->ws()->directory().$args->{filename}) {
    	return "Failed! Could not find specified file: ".$self->ws()->directory().$args->{filename}."!";
    }
    my $array = [split(/\./,$args->{filename})];
    my $type = pop(@{$array});
    my $data = ModelSEED::utilities::LOADFILE($self->ws()->directory().$args->{filename});
    my $datahash = {};
    for (my $i=0; $i < @{$data}; $i++) {
    	my $linearray = [split(/\t/,$data->[$i])];
    	if (defined($linearray->[1])) {
    		$datahash->{$linearray->[0]} = $linearray->[1];
    	}
    }
    $self->db()->create_object($type,$datahash);
    return "Successfully loaded new object of type ".$type." from file ".$self->ws()->directory().$args->{filename}."!";
}
=head
=CATEGORY
Temporary Operations
=DESCRIPTION
This function handles the transition of models in the old database into the new database system
=EXAMPLE
./temptransfermodels 
=cut
sub temptransfermodels {
    my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"model to be transfered"],
	],[@Data],"transitions models in the old database into the new database system");
	my $models = ModelSEED::Interface::interface::PROCESSIDLIST({
		objectType => "model",
		delimiter => ",",
		column => "id",
		parameters => undef,
		input => $args->{model}
	});
	for (my $i=0; $i < @{$models}; $i++) {
		my $obj = $self->db()->get_object("model",{id => $models->[$i]});
		my $mdldir = "/vol/model-dev/MODEL_DEV_DB/Models2/".$obj->owner()."/".$models->[$i]."/".$obj->version()."/";
		if (!-d $mdldir) {
			print "Generating provenance for ".$models->[$i]."!\n";
			File::Path::mkpath $mdldir."biochemistry/";
			File::Path::mkpath $mdldir."mapping/";
			File::Path::mkpath $mdldir."annotations/";
			system("cp /vol/model-dev/MODEL_DEV_DB/Models2/master/Seed83333.1/0/biochemistry/* ".$mdldir."biochemistry/");
			system("cp /vol/model-dev/MODEL_DEV_DB/Models2/master/Seed83333.1/0/mapping/* ".$mdldir."mapping/");
#			if (lc($obj->genome()) ne "unknown" && lc($obj->genome()) ne "none") {	
#				my $genome = $self->figmodel()->get_genome($obj->genome());
#				if (defined($genome)) {
#					my $feature_table = $genome->feature_table();
#					$feature_table->save($mdldir.'annotations/features.txt');
#				}
#			}				
		}
		my $objs = $self->db()->get_objects("rxnmdl",{MODEL => $models->[$i]});
		my $numRxn = @{$objs};
		if ($numRxn == 0) {
			print "Model ".$models->[$i]." is empty. Populating rxnmdl table!\n";
			my $mdltbl = ModelSEED::FIGMODEL::FIGMODELTable::load_table("/vol/model-dev/MODEL_DEV_DB/Models/".$obj->owner()."/".$obj->genome()."/".$models->[$i].".txt",";","|",0,undef);
			if (defined($mdltbl)) {
				for (my $j=0; $j < $mdltbl->size(); $j++) {
					my $row = $mdltbl->get_row($j);
					if (defined($row->{LOAD}->[0])) {
						if (!defined($row->{DIRECTIONALITY})) {
							$row->{DIRECTIONALITY}->[0] = "<=>";
						}
						if (!defined($row->{COMPARTMENT})) {
							$row->{COMPARTMENT}->[0] = "c";
						}
						if (!defined($row->{REFERENCE})) {
							$row->{REFERENCE}->[0] = "none";
						}
						if (!defined($row->{NOTES})) {
							$row->{NOTES}->[0] = "none";
						}
						if (!defined($row->{CONFIDENCE})) {
							$row->{CONFIDENCE}->[0] = 5;
						}
						if (!defined($row->{"ASSOCIATED PEG"})) {
							$row->{"ASSOCIATED PEG"}->[0] = "UNKNOWN";
						}
						$self->db()->create_object("rxnmdl",{
							MODEL => $models->[$i],
							REACTION => $row->{LOAD}->[0],
							directionality => $row->{DIRECTIONALITY}->[0],
							compartment => $row->{COMPARTMENT}->[0],
							pegs => join("|",@{$row->{"ASSOCIATED PEG"}}),
							confidence => $row->{CONFIDENCE}->[0],
							notes => join("|",@{$row->{NOTES}}),
							reference => join("|",@{$row->{REFERENCE}})
						});
					}
				}
			} else {
				print "Model ".$models->[$i]." reaction table not found!\n";
			}
		} elsif ($numRxn > 100) {
			print "Model ".$models->[$i]." fully populated!\n";
		} else {
			print "Model ".$models->[$i]." appears to be too small!\n";	
		}
	}
    return "SUCCESS";
}
=head
=CATEGORY
Workspace Operations
=DESCRIPTION
Sometimes rather than importing an account from the SEED (which you would do using the ''mslogin'' command), you want to create a stand-alone account in the local Model SEED database only. To do this, use the ''createlocaluser'' binary. Once the local account exists, you can use the ''login'' binary to log into your local Model SEED account. This allows you to access, create, and manipulate private data in your local database. HOWEVER, because this is a local account only, you will not be able to use the account to access any private data in the SEED system. For this reason, we recommend importing a SEED account using the ''login'' binary rather than making local accounts with no SEED equivalent. If you require a SEED account, please go to the registration page: [http://pubseed.theseed.org/seedviewer.cgi?page=Register SEED account registration].
=EXAMPLE
./mscreateuser -login "username" -password "password" -firstname "my firstname" -lastname "my lastname" -email "my email"
=cut
sub mscreateuser {
    my($self,@Data) = @_;
	my $args = $self->check([
		["login",1,undef,"Login name of the new user account."],
		["password",1,undef,"Password for the new user account, which will be stored in encryted form."],
		["firstname",1,undef,"First name of the new proposed user."],
		["lastname",1,undef,"Last name of the new proposed user."],
		["email",1,undef,"Email of the new proposed user."]
	],[@Data],"creating a new local account for a model SEED installation");
	if ($self->figmodel()->config("PPO_tbl_user")->{name}->[0] ne "ModelDB") {
		ModelSEED::utilities::ERROR("Cannot use this function to add user to any database except ModelDB");
	}
	my $usr = $self->db()->get_object("user",{login => $args->{login}});
	if (defined($usr)) {
		ModelSEED::utilities::ERROR("User with login ".$args->{login}." already exists!");	
	}
	$usr = $self->db()->create_object("user",{
		login => $args->{login},
		password => "NONE",
		firstname => $args->{"firstname"},
		lastname => $args->{"lastname"},
		email => $args->{email}
	});
	$usr->set_password($args->{password});
    return "SUCCESS";
}

=head
=CATEGORY
Workspace Operations
=DESCRIPTION
This function deletes the local copy of the specified user account from the local Model SEED distribution. This function WILL NOT delete accounts from the centralized SEED database.
=EXAMPLE
./msdeleteuser -login "username" -password "password"
=cut
sub msdeleteuser {
    my($self,@Data) = @_;
	my $args = $self->check([
		["login",0,$ENV{FIGMODEL_USER},"Login of the useraccount to be deleted."],
		["password",0,$ENV{FIGMODEL_PASSWORD},"Password of the useraccount to be deleted."],
	],[@Data],"deleting the local instantiation of the specified user account");
	if ($self->config("PPO_tbl_user")->{host}->[0] eq "bio-app-authdb.mcs.anl.gov") {
		ModelSEED::utilities::ERROR("This function cannot be used in the centralized SEED database!");
	}
	$self->figmodel()->authenticate($args);
	if (!defined($self->figmodel()->userObj()) || $self->figmodel()->userObj()->login() ne $args->{username}) {
		ModelSEED::utilities::ERROR("No account found that matches the input credentials!");
	}
	$self->figmodel()->userObj()->delete();
	return "Account successfully deleted!\n";
}

=head
=CATEGORY
Workspace Operations
=DESCRIPTION
This function is used to switch to a new workspace in the Model SEED environment. Workspaces are used to organize input and output files created and used during interactions with the Model SEED.
=EXAMPLE
./msswitchworkspace -name MyNewWorkspace
=cut
sub msswitchworkspace {
    my($self,@Data) = @_;
	my $args = $self->check([
		["name",1,undef,"Name of a new or existing workspace you want to switch to."],
		["clear",0,0,"Indicates that the workspace should be cleared upon switching to it."],
		["copy",0,undef,"The name of an existing workspace that should be copied into the new specified workspace."],
	],[@Data],"switch to a new workspace");
	my $id = ModelSEED::Interface::interface::WORKSPACE()->id();
	ModelSEED::Interface::interface::WORKSPACE()->switchWorkspace({
		id => $args->{name},
		copy => $args->{copy},
		clear => $args->{clear}
	});
	my $output = {MESSAGE => [
		"Switched from workspace ".$id." to workspace ".ModelSEED::Interface::interface::WORKSPACE()->id()."!"
	]};
	return join("\n",@{$output->{MESSAGE}})."\n";
}

=head
=CATEGORY
Workspace Operations
=DESCRIPTION
This function is used to change the current directory to the currently selected workspace directory
=EXAMPLE
./msswitchworkspace -name MyNewWorkspace
=cut
sub msgoworkspace {
    my($self,@Data) = @_;
	my $args = $self->check([],[@Data],"changes current directory to ");
	my $id = ModelSEED::Interface::interface::WORKSPACE()->id();
	ModelSEED::Interface::interface::WORKSPACE()->switchWorkspace({
		id => $args->{name},
		copy => $args->{copy},
		clear => $args->{clear}
	});
	my $output = {MESSAGE => [
		"Switched from workspace ".$id." to workspace ".ModelSEED::Interface::interface::WORKSPACE()->id()."!"
	]};
	return join("\n",@{$output->{MESSAGE}})."\n";
}

=head
=CATEGORY
Workspace Operations
=DESCRIPTION
Prints data on the contents and metadata of the current workspace.
=EXAMPLE
./msworkspace
=cut
sub msworkspace {
    my($self,@Data) = @_;
	my $args = $self->check([
		["verbose",0,0,"Set this FLAG to '1' to print more details about workspace contents and metadata."]
	],[@Data],"prints workspace information");
	my $output = {MESSAGE => ModelSEED::Interface::interface::WORKSPACE()->printWorkspace({
		verbose => $args->{verbose}
	})};
	return join("\n",@{$output->{MESSAGE}})."\n";
}

=head
=CATEGORY
Workspace Operations
=DESCRIPTION
Prints a list of all workspaces owned by the specified or currently logged user.
=EXAMPLE
./mslistworkspace
=cut
sub mslistworkspace {
    my($self,@Data) = @_;
	my $args = $self->check([
		["user",0,ModelSEED::Interface::interface::USERNAME(),"username to list workspaces for"]
	],[@Data],"print list of workspaces for user");
	my $list = ModelSEED::Interface::interface::WORKSPACE()->listWorkspaces({
		owner => $args->{user}
	});
	my $output = {MESSAGE => [
		"Current workspaces for user ".$args->{user}.":"
	]};
	push(@{$output->{MESSAGE}},@{$list});
	return join("\n",@{$output->{MESSAGE}})."\n";
}

=head
=CATEGORY
Workspace Operations
=DESCRIPTION
This command is used to login as a user in the Model SEED environment. If you have a SEED account already, use those credentials to log in here. Your account information will automatically be imported and used locally. You will remain logged in until you use either the '''mslogin''' or '''mslogout''' command. Once you login, you will automatically switch to the current workspace for the account you log into.
=EXAMPLE
./mslogin -username public -password public
=cut
sub mslogin {
    my($self,@Data) = @_;
	my $args = $self->check([
		["username",1,undef,"username of user account you wish to log into or import from the SEED"],
		["password",1,undef,"password of user account you wish to log into or import from the SEED"],
		["noimport",0,0,undef,"username of user account you wish to log into"]
	],[@Data],"login as new user and import user account from SEED");
	#Checking for existing account in local database
	my $usrObj = $self->db()->get_object("user",{login => $args->{username}});
	if (!defined($usrObj) && $self->figmodel()->config("PPO_tbl_user")->{name}->[0] ne "ModelDB") {
		ModelSEED::utilities::ERROR("Could not find specified user account. Try new \"username\" or register an account on the SEED website!");
	}
	#If local account was not found, attempting to import account from the SEED
	if (!defined($usrObj) && $args->{noimport} == 0) {
        print "Unable to find account locally, trying to obtain login info from theseed.org...\n";
		$usrObj = $self->figmodel()->import_seed_account({
			username => $args->{username},
			password => $args->{password}
		});
		if (!defined($usrObj)) {
			ModelSEED::utilities::ERROR("Could not find specified user account in the local or SEED environment.".
                "Try new \"username\", run \"createlocaluser\", or register an account on the SEED website.");
		}
        print "Success! Downloaded user credentials from theseed.org!\n";
	}
	my $oldws = ModelSEED::Interface::interface::USERNAME().":".ModelSEED::Interface::interface::WORKSPACE()->id();
	#Authenticating
	$self->figmodel()->authenticate($args);
	if (!defined($self->figmodel()->userObj()) || $self->figmodel()->userObj()->login() ne $args->{username}) {
		ModelSEED::utilities::ERROR("Authentication failed! Try new password!");
	}
	ModelSEED::Interface::interface::SWITCHUSER($args->{username},$self->figmodel()->userObj()->password());
	return "Authentication Successful!\n".
		"You will remain logged in as \"".$args->{username}."\" until you run the \"login\" or \"logout\" functions.".
		"You have switched from workspace \"".$oldws."\" to workspace \"".$args->{username}.":".$self->ws()->id()."\"!";
}

=head
=CATEGORY
Workspace Operations
=DESCRIPTION
This function is used to log a user out of the Model SEED environment. Effectively, this switches the currently logged user to the "public" account and switches to the current workspace for the public account.
=EXAMPLE
./mslogout
=cut
sub mslogout {
    my($self,@Data) = @_;
	my $args = $self->check([
	],[@Data],"logout of the Model SEED environment");
	my $oldws = ModelSEED::Interface::interface::USERNAME().":".ModelSEED::Interface::interface::WORKSPACE()->id();
	ModelSEED::Interface::interface::SWITCHUSER("public","public");
	my $output = {MESSAGE => [
		"Logout Successful!",
		"You will not be able to access user-associated data anywhere unless you log in again.",
		"You have switched from workspace \"".$oldws."\" to workspace \"public:".ModelSEED::Interface::interface::WORKSPACE()->id()."\"!"
	]};
	return join("\n",@{$output->{MESSAGE}})."\n";
}
=head
=CATEGORY
Workpsace Operations
=DESCRIPTION
This function will tell the user what account is currently logged
into the Model SEED environment. Use -v flag for a detailed description
including currently active workspace.
=EXAMPLE
./ms-whoami
=cut
sub mswhoami {
    my ($self, @Data) = @_;
    #my $args = $self->check([["verbose"]], [@Data], "print the currently logged in user in the environment");
    my $username = ModelSEED::Interface::interface::USERNAME();
    return "No logged in user" unless(defined($username));
    my $str = $username;
    #if($args->{v}) {
    #    my $ws = $self->figmodel()->ws()->id();
    #    $str = "Currently logged in as: $username\nwith workspace: $ws\n";
    #}
    return $str;
}
=head
=CATEGORY
Workpsace Operations
=DESCRIPTION
This function prints the last error file to screen, as well as printing filename.
=EXAMPLE
./ms-lasterror
=cut
sub mslasterror {
    my ($self, @Data) = @_;
    my $args = $self->check([
	],[@Data],"print last error");
	if (ModelSEED::Interface::interface::LASTERROR() eq "NONE" || !-e ModelSEED::Interface::interface::LASTERROR()) {
		return "Last error file not found!";
	}
	my $output = ["Last error printed to file:","",ModelSEED::Interface::interface::LASTERROR(),"","Error text printed below:"];
	push(@{$output},@{ModelSEED::utilities::LOADFILE(ModelSEED::Interface::interface::LASTERROR())});
    return join("\n",@{$output});
}
=head
=CATEGORY
Sequence Analysis Operations
=DESCRIPTION
This function will blast one or more specified sequences against one or more specified genomes. Results will be printed in a file in the current workspace.
=EXAMPLE
./sqblastgenomes -sequences CCGAGACGGGGACGAG -genomes 83333.1
=cut
sub sqblastgenomes {
    my($self,@Data) = @_;
	my $args = $self->check([
		["sequences",1,undef,"A ',' delimited list of nucelotide sequences that should be blasted against the specified genome sequences. You may also provide the name of a file in the workspace where sequences have been listed. The file must have the '.lst' extension."],
		["genomes",1,undef,"A ',' delimited list of the genome IDs that the input sequence should be blasted against. You may also provide the name of a file in the workspace where genome IDs have been listed. The file must have the '.lst' extension."],
		["filename",0,"sqblastgenomes.out","The name of the file where the output from the blast should be saved."]
	],[@Data],"blast sequences against genomes");
	my $genomes = ModelSEED::Interface::interface::PROCESSIDLIST({
		objectType => "genome",
		delimiter => ",",
		column => "id",
		parameters => undef,
		input => $args->{"genomes"}
	});
	my $sequences = ModelSEED::Interface::interface::PROCESSIDLIST({
		objectType => "sequence",
		delimiter => ",",
		column => "id",
		parameters => undef,
		input => $args->{"sequences"}
	});
	my $svr = $self->figmodel()->server("MSSeedSupportClient");
	my $results = $svr->blast_sequence({
    	sequences => $sequences,
    	genomes => $genomes
    });
    my $headings = [
    	"sequence",
    	"genome",
    	"qstart",
    	"length",
    	"evalue",
    	"identity",
    	"tstart",
    	"tend",
    	"qend",
    	"bitscore"
    ];
    my $output = [join("\t",@{$headings})];
    foreach my $sequence (keys(%{$results})) {
    	foreach my $genome (keys(%{$results->{$sequence}})) {
    		my $line = $sequence."\t".$genome;
    		for (my $i=0; $i < @{$headings}; $i++) {
    			$line .= "\t".$results->{$sequence}->{$genome}->{$headings->[$i]};
    		}
    		push(@{$output},$line);
    	}
    }
	ModelSEED::utilities::PRINTFILE($self->ws->directory().$args->{"filename"},$output);
}

=head
=CATEGORY
Flux Balance Analysis Operations
=DESCRIPTION
This function is used to test if a model grows under a specific media, Complete media is used as default. Users can set the specific media to test model growth and set parameters for the FBA run. The FBA problem can be managed via optional parameters to set the problem directory and save the linear problem associated with the FBA run.
=EXAMPLE
./bin/ModelDriver '''fbacheckgrowth''' '''-model''' iJR904
=cut
sub fbacheckgrowth {
    my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"Full ID of the model to be analyzed"],
		["media",0,"Complete","Name of the media condition in the Model SEED database in which the analysis should be performed. May also provide the name of a [[Media File]] in the workspace where media has been defined. This file MUST have a '.media' extension."],
		["rxnKO",0,undef,"A ',' delimited list of reactions to be knocked out during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where reactions to be knocked out are listed. This file MUST have a '.lst' extension."],
		["geneKO",0,undef,"A ',' delimited list of genes to be knocked out during the analysis. May also provide the name of a [[Gene Knockout File]] in the workspace where genes to be knocked out are listed. This file MUST have a '.lst' extension."],
		["drainRxn",0,undef,"A ',' delimited list of reactions whose reactants will be added as drain fluxes in the model during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where drain reactions are listed. This file MUST have a '.lst' extension."],
		["uptakeLim",0,undef,"Specifies limits on uptake of various atoms. For example 'C:1;S:5'"],
		["options",0,undef,"A ';' delimited list of optional keywords that toggle the use of various additional constrains during the analysis. See [[Flux Balance Analysis Options Documentation]]."],
		["fbajobdir",0,undef,"Set directory in which FBA problem output files will be stored."],
		["savelp",0,0,"User can choose to save the linear problem associated with the FBA run."]
	],[@Data],"tests if a model is growing under a specific media");
	$args->{media} =~ s/\_/ /g;
	my $models = ModelSEED::Interface::interface::PROCESSIDLIST({
		objectType => "model",
		delimiter => ",",
		column => "id",
		parameters => {},
		input => $args->{"model"}
	});
	if (@{$models} > 1) {
		for (my $i=0; $i < @{$models}; $i++) {
			$args->{model} = $models->[$i];
			$self->figmodel()->queue()->queueJob({
				function => "fbacheckgrowth",
				arguments => $args
			});
		}	
	}
	my $fbaStartParameters = $self->figmodel()->fba()->FBAStartParametersFromArguments({arguments => $args});
    my $mdl = $self->figmodel()->get_model($args->{model});
    if (!defined($mdl)) {
	ModelSEED::utilities::ERROR("Model ".$args->{model}." not found in database!");
    }
	my $results = $mdl->fbaCalculateGrowth({
        fbaStartParameters => $fbaStartParameters,
        problemDirectory => $fbaStartParameters->{filename},
        saveLPfile => $args->{"save lp file"}
    });
	if (!defined($results->{growth})) {
		ModelSEED::utilities::ERROR("FBA growth test of ".$args->{model}." failed!");
	}
	my $message = "";
	if ($results->{growth} > 0.000001) {
		if (-e $results->{fbaObj}->directory()."/MFAOutput/SolutionReactionData.txt") {
			system("cp ".$results->{fbaObj}->directory()."/MFAOutput/SolutionReactionData.txt ".$self->ws()->directory()."Fluxes-".$mdl->id()."-".$args->{media}.".txt");
			system("cp ".$results->{fbaObj}->directory()."/MFAOutput/SolutionCompoundData.txt ".$self->ws()->directory()."CompoundFluxes-".$mdl->id()."-".$args->{media}.".txt");  
		}
		$message .= $args->{model}." grew in ".$args->{media}." media with rate:".$results->{growth}." gm biomass/gm CDW hr.\n"
	} else {
		$message .= $args->{model}." failed to grow in ".$args->{media}." media.\n";
		if (defined($results->{noGrowthCompounds}->[0])) {
			$message .= "Biomass compounds ".join(",",@{$results->{noGrowthCompounds}})." could not be generated!\n";
		}
	}
	return $message;
}

=head
=CATEGORY
Flux Balance Analysis Operations
=DESCRIPTION
This function simulates phenotype data
=EXAMPLE
fbasimphenotypes '''-model''' iJR904 -phenotypes InPhenotype.lst
=cut
sub fbasimphenotypes {
    my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"Full ID of the model to be analyzed"],
		["phenotypes",1,undef,"List of phenotypes to be simulated"],
		["modifications",0,undef,"List of modifications to be tested"],
		["accumulateChanges",0,undef,"Accumulate changes that have no effect"],
		["rxnKO",0,undef,"A ',' delimited list of reactions to be knocked out during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where reactions to be knocked out are listed. This file MUST have a '.lst' extension."],
		["geneKO",0,undef,"A ',' delimited list of genes to be knocked out during the analysis. May also provide the name of a [[Gene Knockout File]] in the workspace where genes to be knocked out are listed. This file MUST have a '.lst' extension."],
		["drainRxn",0,undef,"A ',' delimited list of reactions whose reactants will be added as drain fluxes in the model during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where drain reactions are listed. This file MUST have a '.lst' extension."],
		["uptakeLim",0,undef,"Specifies limits on uptake of various atoms. For example 'C:1;S:5'"],
		["options",0,undef,"A ';' delimited list of optional keywords that toggle the use of various additional constrains during the analysis. See [[Flux Balance Analysis Options Documentation]]."],
		["fbajobdir",0,undef,"Set directory in which FBA problem output files will be stored."],
		["savelp",0,0,"User can choose to save the linear problem associated with the FBA run."]
	],[@Data],"tests if a model is growing under a specific media");
	my $fbaStartParameters = $self->figmodel()->fba()->FBAStartParametersFromArguments({arguments => $args});
    my $mdl = $self->figmodel()->get_model($args->{model});
    if (!defined($mdl)) {
		ModelSEED::utilities::ERROR("Model ".$args->{model}." not found in database!");
    }
    my $data = ModelSEED::utilities::LOADFILE($self->ws()->directory().$args->{phenotypes});
	my $input = {
		fbaStartParameters => {},
		findTightBounds => 0,
		deleteNoncontributingRxn => 0,
		identifyCriticalBiomassCpd => 0
	};
	my $phenotypes;
	my $labelArray;
	for (my $i=1; $i < @{$data}; $i++) {
		my $array = [split(/\t/,$data->[$i])];
		push(@{$input->{labels}},$array->[0]."_".$array->[2]);
		push(@{$input->{mediaList}},$array->[2]);
		push(@{$input->{koList}},[split(",",$array->[1])]);
		$phenotypes->{$array->[0]."_".$array->[2]} = {
			label => $array->[0],
			growth => $array->[3],
			media => $array->[2],
			ko => $array->[1]
		};
		$input->{observations}->{$array->[0]}->{$array->[2]} = $array->[3];
	}
	my $result = $mdl->fbaMultiplePhenotypeStudy($input);
	$input->{comparisonResults} = $result;
	my $comparisonResults;
	if (defined($args->{modifications})) {
		#Parsing specified modifications
		my $mods;
		$data = ModelSEED::utilities::LOADFILE($self->ws()->directory().$args->{modifications});
		my $current = 0;
		for (my $i=1; $i < @{$data}; $i++) {
			my $array = [split(/\t/,$data->[$i])];
			if ($array->[4] eq "new" && $i > 1) {
				$current++;
			}
			push(@{$mods->[$current]},{
				type => $array->[0],
				id => $array->[1],
				attribute => $array->[2],
				value => $array->[3]
			});
		}
		#Implementing and testing each set of modifications
		for (my $i=0; $i < @{$mods}; $i++) {
			for (my $j=0; $j < @{$mods->[$i]}; $j++) {
				if ($mods->[$i]->[$j]->{type} eq "model") {
					my $changeInput = {reaction => $mods->[$i]->[$j]->{id},compartment => "c"};
					if ($changeInput->{reaction} =~ m/(rxn.+)\[(.+)\]$/) {
						$changeInput->{reaction} = $1;
						$changeInput->{compartment} = $2;
					}
					if ($mods->[$i]->[$j]->{attribute} ne "remove") {
						my $attArray = [split(/;/,$mods->[$i]->[$j]->{attribute})];
						my $valArray = [split(/;/,$mods->[$i]->[$j]->{value})];
						for (my $k=0; $k < @{$attArray}; $k++) {
							$changeInput->{$attArray->[$k]} = $valArray->[$k]
						}
					}
					$mods->[$i]->[$j]->{restoreInput} = $mdl->change_reaction($changeInput);
				} elsif ($mods->[$i]->[$j]->{type} eq "media") {
					my $array = [split(/\:/,$mods->[$i]->[$j]->{id})];
					my $mediaObj = $mdl->figmodel()->get_media($array->[0]);
					my $changeInput = {compound => $array->[1]};
					if ($mods->[$i]->[$j]->{attribute} eq "uptake" && $mods->[$i]->[$j]->{value} != 0) {
						$changeInput->{maxUptake} = $mods->[$i]->[$j]->{value};
						$changeInput->{minUptake} = -100;
					}
					$mods->[$i]->[$j]->{restoreInput} = $mediaObj->change_compound($changeInput);
				} elsif ($mods->[$i]->[$j]->{type} eq "bof") {
					my $changeInput = {compound => $mods->[$i]->[$j]->{id},compartment => "c"};
					if ($changeInput->{compound} =~ m/(cpd.+)\[(.+)\]$/) {
						$changeInput->{compound} = $1;
						$changeInput->{compartment} = $2;
					}
					if ($mods->[$i]->[$j]->{value} != 0) {
						$changeInput->{coefficient} = $mods->[$i]->[$j]->{value};
					}
					my $bofObj = $mdl->figmodel()->get_reaction($mdl->biomassReaction());
					$mods->[$i]->[$j]->{restoreInput} = $bofObj->change_reactant($changeInput);
				}
			}
			my $newresult = $mdl->fbaMultiplePhenotypeStudy($input);
			if ($args->{accumulateChanges} == 0 ||  $newresult->{comparisonResults}->{"new FP"}->{intervals} > 0 || $newresult->{comparisonResults}->{"new FN"}->{intervals} > 0) {
				push(@{$comparisonResults},{
					status => "rolledback",
					changes => $mods->[$i],
					changedResults => $newresult->{comparisonResults}
				});
				for (my $j=0; $j < @{$mods->[$i]}; $j++) {
					if ($mods->[$i]->[$j]->{type} eq "model") {
						$mdl->change_reaction($mods->[$i]->[$j]->{restoreInput});
					} elsif ($mods->[$i]->[$j]->{type} eq "media") {
						my $array = [split(/\:/,$mods->[$i]->[$j]->{id})];
						my $mediaObj = $mdl->figmodel()->get_media($array->[0]);
						$mediaObj->change_compound($mods->[$i]->[$j]->{restoreInput});
					} elsif ($mods->[$i]->[$j]->{type} eq "bof") {
						my $bofObj = $mdl->figmodel()->get_reaction($mdl->biomassReaction());
						$bofObj->change_reactant($mods->[$i]->[$j]->{restoreInput});
					}
				}
			} else {
				push(@{$comparisonResults},{
					status => "retained",
					changes => $mods->[$i],
					changedResults => $newresult->{comparisonResults}
				});	
			}
		}
		my $comparisonOutput = ["New set\tType\tID\tAttribute\tValue\tStatus\tTotal intervals\tTotal phenotypes\tNew FP\tNew FN\tNew CP\tNew CN\t0 to 1\t1 to 0\tNew FP\tNew FN\tNew CP\tNew CN\t0 to 1\t1 to 0\tNew FP\tNew FN\tNew CP\tNew CN\t0 to 1\t1 to 0"];
		my $changeTypes = ["new FP","new FN","new CP","new CN","0 to 1","1 to 0"];
		for (my $i=0; $i < @{$comparisonResults}; $i++) {
			for (my $j=0; $j < @{$comparisonResults->[$i]->{changes}}; $j++) {
				my $line = $i."\t".$comparisonResults->[$i]->{changes}->[$j]->{type}."\t".$comparisonResults->[$i]->{changes}->[$j]->{id}
					."\t".$comparisonResults->[$i]->{changes}->[$j]->{attribute}."\t".$comparisonResults->[$i]->{changes}->[$j]->{value}
					."\t".$comparisonResults->[$i]->{status}."\t".$comparisonResults->[$i]->{changedResults}->{"Total intervals"}
					."\t".$comparisonResults->[$i]->{changedResults}->{"Total phenotypes"};
				for (my $k=0; $k < @{$changeTypes};$k++) {
					$line .= "\t".$comparisonResults->[$i]->{changedResults}->{$changeTypes->[$k]}->{intervals}."|".$comparisonResults->[$i]->{changedResults}->{$changeTypes->[$k]}->{phenotypes};
				}
				for (my $k=0; $k < @{$changeTypes};$k++) {
					$line .= "\t";
					if (defined($comparisonResults->[$i]->{changedResults}->{$changeTypes->[$k]}->{media})) {
						my $start = 1;
						foreach my $media (keys(%{$comparisonResults->[$i]->{changedResults}->{$changeTypes->[$k]}->{media}})) {
							if ($start != 1) {
								$line .= "|";	
							}
							$line .= $media.":".join(";",@{$comparisonResults->[$i]->{changedResults}->{$changeTypes->[$k]}->{media}->{$media}});
							$start = 0;
						}
					}
				}		
				for (my $k=0; $k < @{$changeTypes};$k++) {
					$line .= "\t";
					if (defined($comparisonResults->[$i]->{changedResults}->{$changeTypes->[$k]}->{label})) {
						my $start = 1;
						foreach my $strain (keys(%{$comparisonResults->[$i]->{changedResults}->{$changeTypes->[$k]}->{label}})) {
							if ($start != 1) {
								$line .= "|";	
							}
							$line .= $strain.":".join(";",@{$comparisonResults->[$i]->{changedResults}->{$changeTypes->[$k]}->{label}->{$strain}});
							$start = 0;
						}
					}
				}
				push(@{$comparisonOutput},$line);
			}
		}
		ModelSEED::utilities::PRINTFILE($self->ws()->directory().$args->{model}."-Comparison.tbl",$comparisonOutput);
	}
	my $output = ["Label\tStrain\tGene KO\tReaction KO\tPredicted growth\tPredicted fraction\tObserved growth\tClass"];
	foreach my $label (@{$input->{labels}}) {
		my $line = $label."\t".$phenotypes->{$label}->{label}."\t".$phenotypes->{$label}->{ko}."\t";
		if (defined($result->{$label})) {
			$line .= $result->{$label}->{rxnKO}."\t".$result->{$label}->{growth}."\t".$result->{$label}->{fraction}."\t";
			$line .= $phenotypes->{$label}->{growth}."\t".$result->{$label}->{class};
		} else {
			$line .= "NA\tNA\tNA\t".$phenotypes->{$label}->{growth}."\tNA";
		}
		push(@{$output},$line);
	}
	ModelSEED::utilities::PRINTFILE($self->ws()->directory().$args->{model}."-Phenotypes.tbl",$output);
}
=head
=CATEGORY
Flux Balance Analysis Operations
=DESCRIPTION
This function is used to identify what must be removed from a model to correct a false positive prediction
=EXAMPLE
./fba-correctfp -model iJR904
=cut
sub fbaGapGen {
    my($self,@Data) = @_;
    my $args = $self->check([
		["model",1,undef,"Full ID of the model to be analyzed"],
		["numsolutions",0,1,"number of solutions requested"],
		["media",0,"Complete","Name of the media condition in the Model SEED database in which the analysis should be performed. May also provide the name of a [[Media File]] in the workspace where media has been defined. This file MUST have a '.media' extension."],
		["rxnKO",0,undef,"A ',' delimited list of reactions to be knocked out during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where reactions to be knocked out are listed. This file MUST have a '.lst' extension."],
		["geneKO",0,undef,"A ',' delimited list of genes to be knocked out during the analysis. May also provide the name of a [[Gene Knockout File]] in the workspace where genes to be knocked out are listed. This file MUST have a '.lst' extension."],
		["drainRxn",0,undef,"A ',' delimited list of reactions whose reactants will be added as drain fluxes in the model during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where drain reactions are listed. This file MUST have a '.lst' extension."],
		["uptakeLim",0,undef,"Specifies limits on uptake of various atoms. For example 'C:1;S:5'"],
		["options",0,"forcedGrowth","A ';' delimited list of optional keywords that toggle the use of various additional constrains during the analysis. See [[Flux Balance Analysis Options Documentation]]."],
		["controlRxnKO",0,"none","reaction KO in control condition"],
		["controlGeneKO",0,"none","gene KO in control condition"],
		["controlMedia",0,"none","media control condition"]
	],[@Data],"remove reactions to make reactions essential or eliminate growth in media");
    my $targetParameters = $self->figmodel()->fba()->FBAStartParametersFromArguments({arguments => $args});
    my $referenceParameters = $self->figmodel()->fba()->FBAStartParametersFromArguments({arguments => {
    	media => $args->{controlMedia},
    	rxnKO => $args->{controlRxnKO},
    	geneKO => $args->{controlGeneKO}
    }});
    my $mdl = $self->figmodel()->get_model($args->{model});
    if (!defined($mdl)) {
		ModelSEED::utilities::ERROR("Model ".$args->{model}." not found in database!");
    }
    my $results = $mdl->fbaGapGen({
	   	numSolutions => $args->{numsolutions},
	   	targetParameters => $targetParameters,
	   	referenceParameters => $referenceParameters
	});
	if (!defined($results) || !defined($results->{solutions})) {
		return "Gap generation failed for ".$args->{model}." in ".$args->{media}." media.";
	}
	my $output = ["Objective\tReactions"];
	for (my $i=0; $i < @{$results->{solutions}}; $i++) {
		push(@{$output},$results->{solutions}->[$i]->{objective}."\t".join(",",@{$results->{solutions}->[$i]->{reactions}}));
	}
	ModelSEED::utilities::PRINTFILE($self->ws()->directory().$args->{model}."-fbaGapGene.txt",$output);
	return "Successfully completed gapgen analysis of ".$args->{model}." in ".$args->{media}.". Results printed in ".$self->ws()->directory().$args->{model}."-fbaGapGene.txt";
}
=head
=CATEGORY
Flux Balance Analysis Operations
=DESCRIPTION
This function is used to simulate the knockout of all combinations of one or more genes in a SEED metabolic model.
=EXAMPLE
./fbasingleko -model iJR904
=cut
sub fbasingleko {
    my($self,@Data) = @_;
    my $args = $self->check([
		["model",1,undef,"Full ID of the model to be analyzed"],
		["media",0,"Complete","Name of the media condition in the Model SEED database in which the analysis should be performed. May also provide the name of a [[Media File]] in the workspace where media has been defined. This file MUST have a '.media' extension."],
		["rxnKO",0,undef,"A ',' delimited list of reactions to be knocked out during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where reactions to be knocked out are listed. This file MUST have a '.lst' extension."],
		["geneKO",0,undef,"A ',' delimited list of genes to be knocked out during the analysis. May also provide the name of a [[Gene Knockout File]] in the workspace where genes to be knocked out are listed. This file MUST have a '.lst' extension."],
		["drainRxn",0,undef,"A ',' delimited list of reactions whose reactants will be added as drain fluxes in the model during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where drain reactions are listed. This file MUST have a '.lst' extension."],
		["uptakeLim",0,undef,"Specifies limits on uptake of various atoms. For example 'C:1;S:5'"],
		["options",0,"forcedGrowth","A ';' delimited list of optional keywords that toggle the use of various additional constrains during the analysis. See [[Flux Balance Analysis Options Documentation]]."],
		["maxDeletions",0,1,"A number specifying the maximum number of simultaneous knockouts to be simulated. We donot recommend specifying more than 2."],
		["savetodb",0,0,"A FLAG that indicates that results should be saved to the database if set to '1'."],
		["filename",0,undef,"The filename to which the list of gene knockouts that resulted in reduced growth should be printed."]
	],[@Data],"simulate knockout of all combinations of one or more genes");
    my $fbaStartParameters = $self->figmodel()->fba()->FBAStartParametersFromArguments({arguments => $args});
    my $mdl = $self->figmodel()->get_model($args->{model});
    if (!defined($mdl)) {
	ModelSEED::utilities::ERROR("Model ".$args->{model}." not found in database!");
    }
    if (!defined($args->{filename})) {
    	$args->{filename} = $mdl->id()."-EssentialGenes.lst"; 
    }
    my $results = $mdl->fbaComboDeletions({
	   	maxDeletions => $args->{maxDeletions},
	   	fbaStartParameters => $fbaStartParameters,
		saveKOResults=>$args->{savetodb},
	});
	if (!defined($results) || !defined($results->{essentialGenes})) {
		return "Single gene knockout failed for ".$args->{model}." in ".$args->{media}." media.";
	}
	ModelSEED::utilities::PRINTFILE($self->ws()->directory().$args->{"filename"},$results->{essentialGenes});
	return "Successfully completed flux variability analysis of ".$args->{model}." in ".$args->{media}.". Results printed in ".$self->ws()->directory().$args->{"filename"}.".";
}
=head
=CATEGORY
Flux Balance Analysis Operations
=DESCRIPTION 
=EXAMPLE

=cut
sub fbageneactivityanalysis {
	my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"Full ID of the model to be analyzed"],
		["geneCalls",1,undef,"File with gene calls"],
		["rxnKO",0,undef,"A ',' delimited list of reactions to be knocked out during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where reactions to be knocked out are listed. This file MUST have a '.lst' extension."],
		["geneKO",0,undef,"A ',' delimited list of genes to be knocked out during the analysis. May also provide the name of a [[Gene Knockout File]] in the workspace where genes to be knocked out are listed. This file MUST have a '.lst' extension."],
		["drainRxn",0,undef,"A ',' delimited list of reactions whose reactants will be added as drain fluxes in the model during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where drain reactions are listed. This file MUST have a '.lst' extension."],
		["uptakeLim",0,undef,"Specifies limits on uptake of various atoms. For example 'C:1;S:5'"],
		["options",0,undef,"A ';' delimited list of optional keywords that toggle the use of various additional constrains during the analysis. See [[Flux Balance Analysis Options Documentation]]."],
	],[@Data],"");
	my $fbaStartParameters = $self->figmodel()->fba()->FBAStartParametersFromArguments({arguments => $args});
    my $mdl = $self->figmodel()->get_model($args->{model});
    if (!defined($mdl)) {
		ModelSEED::utilities::ERROR("Model ".$args->{model}." not found in database!");
    }
    if (!-e $self->ws()->directory().$args->{geneCalls}) {
    	ModelSEED::utilities::ERROR("Could not find gene call file ".$self->ws()->directory().$args->{geneCalls});
    }
    my $data = ModelSEED::utilities::LOADFILE($self->ws()->directory().$args->{geneCalls});
    my $calls;
    for (my $i=0; $i < @{$data}; $i++) {
    	my $array = [split(/\t/,$data->[$i])];
    	for (my $j=1; $j < @{$array}; $j++) {
    		push(@{$calls->{$array->[0]}},$array->[$j]);
    	}
    }
    my $result = $mdl->fbaGeneActivityAnalysis({
    	fbaStartParameters => $fbaStartParameters,
    	geneCalls => $calls
    });
	#if (defined($result->{})) {
		my $output;
		ModelSEED::utilities::PRINTFILE($self->ws()->directory().$args->{model}."-GeneActivityAnalysis.txt",$output);
	#}
}
=head
=CATEGORY
Flux Balance Analysis Operations
=DESCRIPTION
This function utilizes flux balance analysis to calculate a minimal media for the specified model. 
=EXAMPLE
./fbaminimalmedia -model iJR904
=cut
sub fbaminimalmedia {
	my($self,@Data) = @_;
	 my $args = $self->check([
		["model",1,undef,"Full ID of the model to be analyzed"],
		["numsolutions",0,1,"Indicates the number of alternative minimal media formulations that should be calculated"],
		["rxnKO",0,undef,"A ',' delimited list of reactions to be knocked out during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where reactions to be knocked out are listed. This file MUST have a '.lst' extension."],
		["geneKO",0,undef,"A ',' delimited list of genes to be knocked out during the analysis. May also provide the name of a [[Gene Knockout File]] in the workspace where genes to be knocked out are listed. This file MUST have a '.lst' extension."],
		["drainRxn",0,undef,"A ',' delimited list of reactions whose reactants will be added as drain fluxes in the model during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where drain reactions are listed. This file MUST have a '.lst' extension."],
		["uptakeLim",0,undef,"Specifies limits on uptake of various atoms. For example 'C:1;S:5'"],
		["options",0,"forcedGrowth","A ';' delimited list of optional keywords that toggle the use of various additional constrains during the analysis. See [[Flux Balance Analysis Options Documentation]]."],
	],[@Data],"calculates the minimal media for the specified model");
	my $fbaStartParameters = $self->figmodel()->fba()->FBAStartParametersFromArguments({arguments => $args});
    my $mdl = $self->figmodel()->get_model($args->{model});
    if (!defined($mdl)) {
		ModelSEED::utilities::ERROR("Model ".$args->{model}." not found in database!");
    }
    my $result = $mdl->fbaCalculateMinimalMedia({
    	fbaStartParameters => $fbaStartParameters,
    	numsolutions => $args->{numsolutions}
    });
	if (defined($result->{essentialNutrients}) && defined($result->{optionalNutrientSets}->[0])) {
		my $count = @{$result->{essentialNutrients}};
		my $output;
		my $line = "Essential nutrients (".$count."):";
		for (my $j=0; $j < @{$result->{essentialNutrients}}; $j++) {
			if ($j > 0) {
				$line .= ";";
			}
			my $cpd = $self->db()->get_object("compound",{id => $result->{essentialNutrients}->[$j]});
			$line .= $result->{essentialNutrients}->[$j]."(".$cpd->name().")";
		}
		push(@{$output},$line);
		for (my $i=0; $i < @{$result->{optionalNutrientSets}}; $i++) {
			my $count = @{$result->{optionalNutrientSets}->[$i]};
			$line = "Optional nutrients ".($i+1)." (".$count."):";
			for (my $j=0; $j < @{$result->{optionalNutrientSets}->[$i]}; $j++) {
				if ($j > 0) {
					$line .= ";";	
				}
				my $cpd = $self->db()->get_object("compound",{id => $result->{optionalNutrientSets}->[$i]->[$j]});
				$line .= $result->{optionalNutrientSets}->[$i]->[$j]."(".$cpd->name().")";
			}
			push(@{$output},$line);
		}
		ModelSEED::utilities::PRINTFILE($self->ws()->directory().$args->{model}."-MinimalMediaAnalysis.out",$output);
	}
	if (defined($result->{minimalMedia})) {
		ModelSEED::utilities::PRINTFILE($self->ws()->directory().$args->{model}."-minimal.media",$result->{minimalMedia}->print());
	}
}

=head
=CATEGORY
Flux Balance Analysis Operations
=DESCRIPTION
This function performs FVA analysis, calculating minimal and maximal flux through the reactions (range of fluxes) consistent with maximal theoretical growth rate.
=EXAMPLE
./fbafva '''-model''' iJR904
=cut
sub fbafva {
    my($self,@Data) = @_;
    my $args = $self->check([
		["model",1,undef,"Full ID of the model to be analyzed"],
		["media",0,"Complete","Name of the media condition in the Model SEED database in which the analysis should be performed. May also provide the name of a [[Media File]] in the workspace where media has been defined. This file MUST have a '.media' extension."],
		["rxnKO",0,undef,"A ',' delimited list of reactions to be knocked out during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where reactions to be knocked out are listed. This file MUST have a '.lst' extension."],
		["geneKO",0,undef,"A ',' delimited list of genes to be knocked out during the analysis. May also provide the name of a [[Gene Knockout File]] in the workspace where genes to be knocked out are listed. This file MUST have a '.lst' extension."],
		["drainRxn",0,undef,"A ',' delimited list of reactions whose reactants will be added as drain fluxes in the model during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where drain reactions are listed. This file MUST have a '.lst' extension."],
		["uptakeLim",0,undef,"Specifies limits on uptake of various atoms. For example 'C:1;S:5'"],
		["options",0,"forcedGrowth","A ';' delimited list of optional keywords that toggle the use of various additional constrains during the analysis. See [[Flux Balance Analysis Options Documentation]]. There are three options specifically relevant to the FBAFVA function: (i) the 'forcegrowth' option indicates that biomass must be greater than 10% of the optimal value in all flux distributions explored, (ii) 'nogrowth' means biomass is constrained to zero, and (iii) 'freegrowth' means biomass is left unconstrained."],
		["variables",0,"FLUX;UPTAKE","A ';' delimited list of the variables that should be explored during the flux variability analysis. See [[List and Description of Variables Types used in Model SEED Flux Balance Analysis]]."],	
		["savetodb",0,0,"If set to '1', this flag indicates that the results of the fva should be preserved in the Model SEED database associated with the indicated metabolic model. Database storage of results is necessary for results to appear in the Model SEED web interface."],
		["filename",0,undef,"The name of the file in the user's workspace where the FVA results should be printed. An extension should not be included."],
		["saveformat",0,"EXCEL","The format in which the output of the FVA should be stored. Options include 'EXCEL' or 'TEXT'."],
	],[@Data],"performs FVA (Flux Variability Analysis) studies");
	#$args->{media} =~ s/\_/ /g;
    my $fbaStartParameters = $self->figmodel()->fba()->FBAStartParametersFromArguments({arguments => $args});
    my $mdl = $self->figmodel()->get_model($args->{model});
    if (!defined($mdl)) {
      ModelSEED::utilities::ERROR("Model ".$args->{model}." not found in database!");
    }
    if ($args->{filename} eq "FBAFVA_model ID.xls") {
    	$args->{filename} = undef; 
    }
   	if (!defined($fbaStartParameters->{options}->{forceGrowth})
   		&& !defined($fbaStartParameters->{options}->{nogrowth}) 
   		&& !defined($fbaStartParameters->{options}->{freeGrowth})) {
   		$fbaStartParameters->{options}->{forceGrowth} = 1;
   	}
   	$args->{variables} = [split(/\;/,$args->{variables})];
    my $results = $mdl->fbaFVA({
	   	variables => $args->{variables},
	   	fbaStartParameters => $fbaStartParameters,
		saveFVAResults=>$args->{savetodb},
	});
	if (!defined($results) || defined($results->{error})) {
		return "Flux variability analysis failed for ".$args->{model}." in ".$args->{media}.".";
	}
	if (!defined($args->{filename})) {
		$args->{filename} = $mdl->id()."-fbafvaResults-".$args->{media};
	}
	my $rxntbl = ModelSEED::FIGMODEL::FIGMODELTable->new(["Reaction","Compartment"],$self->ws()->directory()."Reactions-".$args->{filename}.".txt",["Reaction"],";","|");
	my $cpdtbl = ModelSEED::FIGMODEL::FIGMODELTable->new(["Compound","Compartment"],$self->ws()->directory()."Compounds-".$args->{filename}.".txt",["Compound"],";","|");
	my $varAssoc = {
		FLUX => "reaction",
		DELTAG => "reaction",
		SDELTAG => "reaction",
		UPTAKE => "compound",
		SDELTAGF => "compound",
		POTENTIAL => "compound",
		CONC => "compound"
	};
	my $varHeading = {
		FLUX => "",
		DELTAG => " DELTAG",
		SDELTAG => " SDELTAG",
		UPTAKE => "",
		SDELTAGF => " SDELTAGF",
		POTENTIAL => " POTENTIAL",
		CONC => " CONC"
	};
	for (my $i=0; $i < @{$args->{variables}}; $i++) {
		if (defined($varAssoc->{$args->{variables}->[$i]})) {
			if ($varAssoc->{$args->{variables}->[$i]} eq "compound") {
				$cpdtbl->add_headings(("Min ".$args->{variables}->[$i],"Max ".$args->{variables}->[$i]));
				if ($args->{variables}->[$i] eq "UPTAKE") {
					$cpdtbl->add_headings(("Class"));
				}
			} elsif ($varAssoc->{$args->{variables}->[$i]} eq "reaction") {
				$rxntbl->add_headings(("Min ".$args->{variables}->[$i],"Max ".$args->{variables}->[$i]));
				if ($args->{variables}->[$i] eq "FLUX") {
					$rxntbl->add_headings(("Class"));
				}
			}
		}
	}
	foreach my $obj (keys(%{$results->{tb}})) {
		my $newRow;
		if ($obj =~ m/([rb][xi][no]\d+)(\[[[a-z]+\])*/) {
			$newRow->{"Reaction"} = [$1];
			my $compartment = $2;
			if (!defined($compartment) || $compartment eq "") {
				$compartment = "c";
			}
			$newRow->{"Compartment"} = [$compartment];
			#$newRow->{"Direction"} = [$rxnObj->directionality()];
			#$newRow->{"Associated peg"} = [split(/\|/,$rxnObj->pegs())];
			for (my $i=0; $i < @{$args->{variables}}; $i++) {
				if ($varAssoc->{$args->{variables}->[$i]} eq "reaction") {
					if (defined($results->{tb}->{$obj}->{"min".$varHeading->{$args->{variables}->[$i]}})) {
						$newRow->{"Min ".$args->{variables}->[$i]}->[0] = $results->{tb}->{$obj}->{"min".$varHeading->{$args->{variables}->[$i]}};
						$newRow->{"Max ".$args->{variables}->[$i]}->[0] = $results->{tb}->{$obj}->{"max".$varHeading->{$args->{variables}->[$i]}};
						if ($args->{variables}->[$i] eq "FLUX") {
							$newRow->{Class}->[0] = $results->{tb}->{$obj}->{class};
						}
					}
				}
			}
			#print Data::Dumper->Dump([$newRow]);
			$rxntbl->add_row($newRow);
		} elsif ($obj =~ m/(cpd\d+)(\[[[a-z]+\])*/) {
			$newRow->{"Compound"} = [$1];
			my $compartment = $2;
			if (!defined($compartment) || $compartment eq "") {
				$compartment = "c";
			}
			$newRow->{"Compartment"} = [$compartment];
			for (my $i=0; $i < @{$args->{variables}}; $i++) {
				if ($varAssoc->{$args->{variables}->[$i]} eq "compound") {
					if (defined($results->{tb}->{$obj}->{"min".$varHeading->{$args->{variables}->[$i]}})) {
						$newRow->{"Min ".$args->{variables}->[$i]}->[0] = $results->{tb}->{$obj}->{"min".$varHeading->{$args->{variables}->[$i]}};
						$newRow->{"Max ".$args->{variables}->[$i]}->[0] = $results->{tb}->{$obj}->{"max".$varHeading->{$args->{variables}->[$i]}};
						if ($args->{variables}->[$i] eq "FLUX") {
							$newRow->{Class}->[0] = $results->{tb}->{$obj}->{class};
						}
					}
				}
			}
			$cpdtbl->add_row($newRow);
		}
	}
	#Saving data to file
        my $result = "Unrecognized format: $args->{saveformat}";
	if ($args->{saveformat} eq "EXCEL") {
		$self->figmodel()->make_xls({
			filename => $self->ws()->directory().$args->{filename}.".xls",
			sheetnames => ["Compound Bounds","Reaction Bounds"],
			sheetdata => [$cpdtbl,$rxntbl]
		});
		$result = "Successfully completed flux variability analysis of ".$args->{model}." in ".$args->{media}.". Results printed in ".$self->ws()->directory().$args->{filename}.".xls";
	} elsif ($args->{saveformat} eq "TEXT") {
		$cpdtbl->save();
		$rxntbl->save();
		$result = "Successfully completed flux variability analysis of ".$args->{model}." in ".$args->{media}.". Results printed in ".$rxntbl->filename()." and ".$cpdtbl->filename().".";
	}
        return $result;
}

=head
=CATEGORY
Flux Balance Analysis Operations
=DESCRIPTION
This function performs FVA analysis, calculating minimal and maximal flux through all reactions in the database subject to the specified biomass reaction
=EXAMPLE
./fbafvabiomass '''-biomass''' bio00001
=cut
sub fbafvabiomass {
    my($self,@Data) = @_;
    my $args = $self->check([
		["biomass",1,undef,"ID of biomass reaction to be analyzed."],
		["media",0,"Complete","Name of the media condition in the Model SEED database in which the analysis should be performed. May also provide the name of a [[Media File]] in the workspace where media has been defined. This file MUST have a '.media' extension."],
		["rxnKO",0,undef,"A ',' delimited list of reactions to be knocked out during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where reactions to be knocked out are listed. This file MUST have a '.lst' extension."],
		["geneKO",0,undef,"A ',' delimited list of genes to be knocked out during the analysis. May also provide the name of a [[Gene Knockout File]] in the workspace where genes to be knocked out are listed. This file MUST have a '.lst' extension."],
		["drainRxn",0,undef,"A ',' delimited list of reactions whose reactants will be added as drain fluxes in the model during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where drain reactions are listed. This file MUST have a '.lst' extension."],
		["uptakeLim",0,undef,"Specifies limits on uptake of various atoms. For example 'C:1;S:5'"],
		["options",0,"forcedGrowth","A ';' delimited list of optional keywords that toggle the use of various additional constrains during the analysis. See [[Flux Balance Analysis Options Documentation]]. There are three options specifically relevant to the FBAFVA function: (i) the 'forcegrowth' option indicates that biomass must be greater than 10% of the optimal value in all flux distributions explored, (ii) 'nogrowth' means biomass is constrained to zero, and (iii) 'freegrowth' means biomass is left unconstrained."],
		["variables",0,"FLUX;UPTAKE","A ';' delimited list of the variables that should be explored during the flux variability analysis. See [[List and Description of Variables Types used in Model SEED Flux Balance Analysis]]."],	
		["savetodb",0,0,"If set to '1', this flag indicates that the results of the fva should be preserved in the Model SEED database associated with the indicated metabolic model. Database storage of results is necessary for results to appear in the Model SEED web interface."],
		["filename",0,undef,"The name of the file in the user's workspace where the FVA results should be printed. An extension should not be included."],
		["saveformat",0,"EXCEL","The format in which the output of the FVA should be stored. Options include 'EXCEL' or 'TEXT'."],
	],[@Data],"performs FVA (Flux Variability Analysis) study of entire database");
    my $fbaStartParameters = $self->figmodel()->fba()->FBAStartParametersFromArguments({arguments => $args});
    my $rxn = $self->figmodel()->get_reaction($args->{biomass});
    if (!defined($rxn)) {
      ModelSEED::utilities::ERROR("Reaction ".$args->{biomass}." not found in database!");
    }
    if ($args->{filename} eq "FBAFVA_model ID.xls") {
    	$args->{filename} = undef; 
    }
    $fbaStartParameters->{options}->{forceGrowth} = 1;
   	$args->{variables} = [split(/\;/,$args->{variables})];
    my $results = $rxn->determine_coupled_reactions({
    	variables => $args->{variables},
		fbaStartParameters => $fbaStartParameters,
	   	saveFVAResults => $args->{savetodb}
	});
	if (!defined($results->{tb})) {
		return "Flux variability analysis failed for ".$args->{biomass}." in ".$args->{media}.".";
	}
	if (!defined($args->{filename})) {
		$args->{filename} = $args->{biomass}."-fbafvaResults-".$args->{media};
	}
	my $rxntbl = ModelSEED::FIGMODEL::FIGMODELTable->new(["Reaction","Compartment"],$self->ws()->directory()."Reactions-".$args->{filename}.".txt",["Reaction"],";","|");
	my $cpdtbl = ModelSEED::FIGMODEL::FIGMODELTable->new(["Compound","Compartment"],$self->ws()->directory()."Compounds-".$args->{filename}.".txt",["Compound"],";","|");
	my $varAssoc = {
		FLUX => "reaction",
		DELTAG => "reaction",
		SDELTAG => "reaction",
		UPTAKE => "compound",
		SDELTAGF => "compound",
		POTENTIAL => "compound",
		CONC => "compound"
	};
	my $varHeading = {
		FLUX => "",
		DELTAG => " DELTAG",
		SDELTAG => " SDELTAG",
		UPTAKE => "",
		SDELTAGF => " SDELTAGF",
		POTENTIAL => " POTENTIAL",
		CONC => " CONC"
	};
	for (my $i=0; $i < @{$args->{variables}}; $i++) {
		if (defined($varAssoc->{$args->{variables}->[$i]})) {
			if ($varAssoc->{$args->{variables}->[$i]} eq "compound") {
				$cpdtbl->add_headings(("Min ".$args->{variables}->[$i],"Max ".$args->{variables}->[$i]));
				if ($args->{variables}->[$i] eq "UPTAKE") {
					$cpdtbl->add_headings(("Class"));
				}
			} elsif ($varAssoc->{$args->{variables}->[$i]} eq "reaction") {
				$rxntbl->add_headings(("Min ".$args->{variables}->[$i],"Max ".$args->{variables}->[$i]));
				if ($args->{variables}->[$i] eq "FLUX") {
					$rxntbl->add_headings(("Class"));
				}
			}
		}
	}
	foreach my $obj (keys(%{$results->{tb}})) {
		my $newRow;
		if ($obj =~ m/([rb][xi][no]\d+)(\[[[a-z]+\])*/) {
			$newRow->{"Reaction"} = [$1];
			my $compartment = $2;
			if (!defined($compartment) || $compartment eq "") {
				$compartment = "c";
			}
			$newRow->{"Compartment"} = [$compartment];
			#$newRow->{"Direction"} = [$rxnObj->directionality()];
			#$newRow->{"Associated peg"} = [split(/\|/,$rxnObj->pegs())];
			for (my $i=0; $i < @{$args->{variables}}; $i++) {
				if ($varAssoc->{$args->{variables}->[$i]} eq "reaction") {
					if (defined($results->{tb}->{$obj}->{"min".$varHeading->{$args->{variables}->[$i]}})) {
						$newRow->{"Min ".$args->{variables}->[$i]}->[0] = $results->{tb}->{$obj}->{"min".$varHeading->{$args->{variables}->[$i]}};
						$newRow->{"Max ".$args->{variables}->[$i]}->[0] = $results->{tb}->{$obj}->{"max".$varHeading->{$args->{variables}->[$i]}};
						if ($args->{variables}->[$i] eq "FLUX") {
							$newRow->{Class}->[0] = $results->{tb}->{$obj}->{class};
						}
					}
				}
			}
			#print Data::Dumper->Dump([$newRow]);
			$rxntbl->add_row($newRow);
		} elsif ($obj =~ m/(cpd\d+)(\[[[a-z]+\])*/) {
			$newRow->{"Compound"} = [$1];
			my $compartment = $2;
			if (!defined($compartment) || $compartment eq "") {
				$compartment = "c";
			}
			$newRow->{"Compartment"} = [$compartment];
			for (my $i=0; $i < @{$args->{variables}}; $i++) {
				if ($varAssoc->{$args->{variables}->[$i]} eq "compound") {
					if (defined($results->{tb}->{$obj}->{"min".$varHeading->{$args->{variables}->[$i]}})) {
						$newRow->{"Min ".$args->{variables}->[$i]}->[0] = $results->{tb}->{$obj}->{"min".$varHeading->{$args->{variables}->[$i]}};
						$newRow->{"Max ".$args->{variables}->[$i]}->[0] = $results->{tb}->{$obj}->{"max".$varHeading->{$args->{variables}->[$i]}};
						if ($args->{variables}->[$i] eq "FLUX") {
							$newRow->{Class}->[0] = $results->{tb}->{$obj}->{class};
						}
					}
				}
			}
			$cpdtbl->add_row($newRow);
		}
	}
	#Saving data to file
	if ($args->{saveformat} eq "EXCEL") {
		$self->figmodel()->make_xls({
			filename => $self->ws()->directory().$args->{filename}.".xls",
			sheetnames => ["Compound Bounds","Reaction Bounds"],
			sheetdata => [$cpdtbl,$rxntbl]
		});
	} elsif ($args->{saveformat} eq "TEXT") {
		$cpdtbl->save();
		$rxntbl->save();
	}
	return "Successfully completed flux variability analysis of ".$args->{biomass}." in ".$args->{media}.". Results printed in ".$rxntbl->filename()." and ".$cpdtbl->filename().".";
}
=head
=CATEGORY
Biochemistry Operations
=DESCRIPTION
This function is used to print a table of the compounds across multiple media conditions
=EXAMPLE
./bcprintmediatable -media Carbon-D-glucose
=cut
sub bcprintmediatable {
    my($self,@Data) = @_;
	my $args = $self->check([
		["media",1,undef,"Name of the media formulation to be printed."],
		["filename",0,undef,"Name of the file where the media formulation should be printed."]
	],[@Data],"print Model SEED media formulation");
    my $mediaIDs = ModelSEED::Interface::interface::PROCESSIDLIST({
		objectType => "media",
		delimiter => ",",
		column => "id",
		parameters => undef,
		input => $args->{"media"}
	});
	if (!defined($args->{"filename"})) {
		$args->{"filename"} = $args->{"media"}.".media";
	}
	my $mediaHash = $self->db()->get_object_hash({
		type => "mediacpd",
		attribute => "MEDIA",
		parameters => {}
	});
	my $compoundHash;

	for (my $i=0; $i < @{$mediaIDs}; $i++) {
		if (defined($mediaHash->{$mediaIDs->[$i]})) {
			for (my $j=0; $j < @{$mediaHash->{$mediaIDs->[$i]}}; $j++) {
				if ($mediaHash->{$mediaIDs->[$i]}->[$j]->maxFlux() > 0 && $mediaHash->{$mediaIDs->[$i]}->[$j]->type() eq "COMPOUND") {
					$compoundHash->{$mediaHash->{$mediaIDs->[$i]}->[$j]->entity()}->{$mediaIDs->[$i]} = $mediaHash->{$mediaIDs->[$i]}->[$j]->maxFlux();
				}
			}
		}
	}
	my $output = ["Compounds\t".join("\t",@{$mediaIDs})];
	foreach my $compound (keys(%{$compoundHash})) {
		my $line = $compound;
		for (my $i=0; $i < @{$mediaIDs}; $i++) {
			$line .= "\t".$compoundHash->{$compound}->{$mediaIDs->[$i]};
		}
		push(@{$output},$line);
	}
	ModelSEED::utilities::PRINTFILE($self->ws()->directory().$args->{"filename"},$output);
    return "Media ".$args->{"media"}." successfully printed to ".$self->ws()->directory().$args->{filename};
}

=head
=CATEGORY
Biochemistry Operations
=DESCRIPTION
This function is used to print a media formulation to the current workspace.
=EXAMPLE
./bcprintmedia -media Carbon-D-glucose
=cut
sub bcprintmedia {
    my($self,@Data) = @_;
	my $args = $self->check([
		["media",1,undef,"Name of the media formulation to be printed."],
	],[@Data],"print Model SEED media formulation");
    my $media = $self->db()->get_moose_object("media",{id => $args->{media}});
	ModelSEED::utilities::PRINTFILE($self->ws()->directory().$args->{media}.".media",$media->print());
	return "Successfully printed media '".$args->{media}."' to file '". $self->ws()->directory().$args->{media}.".media'!";
}

=head
=CATEGORY
Biochemistry Operations
=DESCRIPTION
This function is used to create or alter a media condition in the Model SEED database given either a list of compounds in the media or a file specifying the media compounds and minimum and maximum uptake rates.
=EXAMPLE
./bcloadmedia '''-name''' Carbon-D-Glucose '''-filename''' Carbon-D-Glucose.txt
=cut
sub bcloadmedia {
    my($self,@Data) = @_;
	my $args = $self->check([
		["media",1,undef,"The name of the media formulation being created or altered."],
		["public",0,0,"Set directory in which FBA problem output files will be stored."],
		["owner",0,(ModelSEED::Interface::interface::USERNAME()),"Login of the user account who will own this media condition."],
		["overwrite",0,0,"If you set this parameter to '1', any existing media with the same input name will be overwritten."]
	],[@Data],"Creates (or alters) a media condition in the Model SEED database");
    my $media;
    if (!-e $self->ws()->directory().$args->{media}) {
    	ModelSEED::utilities::ERROR("Could not find media file ".$self->ws()->directory().$args->{media});
    }
    $media = $self->db()->create_moose_object("media",{db => $self->db(),filedata => ModelSEED::utilities::LOADFILE($self->ws()->directory().$args->{media})});
    $media->syncWithPPODB({overwrite => $args->{overwrite}}); 
    return "Successfully loaded media ".$args->{media}." to database as ".$media->id();
}
=head
=CATEGORY
Biochemistry Operations
=DESCRIPTION
This function is used process the input molfile to calculate thermodynamic properties.
=EXAMPLE
./bcprocessmolfile -compound cpd00001 -mofile cpd00001.mol -directory "workspace/"
=cut
sub bcprocessmolfile {
    my($self,@Data) = @_;
	my $args = $self->check([
		["compound",1,undef,"ID of the compound associated with molfile"],
		["mofile",0,0,"Name of the molfile to be processed"],
		["directory",0,$self->ws()->directory(),"Directory where molfiles are located"],
	],[@Data],"process input molfiles to calculate thermodynamic parameters, formula, and charge");
    my $input = {
    	ids => ModelSEED::Interface::interface::PROCESSIDLIST({
			objectType => "compound",
			delimiter => ";",
			column => "id",
			parameters => {},
			input => $args->{compound}
		}),
		molfiles => ModelSEED::Interface::interface::PROCESSIDLIST({
			objectType => "molfile",
			delimiter => ";",
			column => "filename",
			parameters => {},
			input => $args->{mofile}
		})
    };
    for (my $i=0; $i < @{$input->{molfiles}}; $i++) {
    	$input->{molfiles}->[$i] = $args->{directory}.$input->{molfiles}->[$i];
    }
    my $cpd = $self->figmodel()->get_compound();
	my $results = $cpd->molAnalysis($input);
	my $output = ["id\tmolfile\tgroups\tcharge\tformula\tstringcode\tmass\tdeltaG\tdeltaGerr"];
	my $heading = ["molfile","groups","charge","formula","stringcode","mass","deltaG","deltaGerr"];
	foreach my $id (keys(%{$results})) {
		if (defined($results->{$id})) {
			my $line = $id;
			for (my $i=0; $i < @{$heading}; $i++) {
				$line .= "\t".$results->{$id}->{$heading->[$i]};
			}
			push(@{$output},$line);
		}
	}
	ModelSEED::utilities::PRINTFILE($self->ws()->directory()."MolAnalysis.tbl",$output);
	return "Success. Results printed to ".$self->ws()->directory()."MolAnalysis.tbl file.";
}
=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
Imports a models from other databases into the Model SEED environment.
=EXAMPLE
./bcaddbiochemistry -reactions reactions.tbl -compounds compounds.tbl
=cut
sub bcaddbiochemistry {
    my($self,@Data) = @_;
    my $args = $self->check([
    	["reactions",0,undef,"Name of a file containing reaction definitions"],
    	["compounds",0,undef,"Name of a file containing compound definitions"],
    	["rxnstart",0,"rxn90000","Starting ID space for new reactions"],
    	["cpdstart",0,"cpd90000","Starting ID space for new compounds"],
    ],[@Data],"imports new reactions and compounds to the database");
	my $rxntbl;
	my $cpdtbl;
	if (defined($args->{reactions})) {
		if (!-e $self->ws()->directory().$args->{reactions}) {
			ModelSEED::utilities::ERROR("Reaction file ".$self->ws()->directory().$args->{reactions}." not found!");
		}
		$rxntbl = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->ws()->directory().$args->{reactions},"\t","|",0,["ID"]);
	}
	if (defined($args->{compounds})) {
		if (!-e $self->ws()->directory().$args->{compounds}) {
			ModelSEED::utilities::ERROR("Compound file ".$self->ws()->directory().$args->{compounds}." not found!");
		}
		$cpdtbl = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->ws()->directory().$args->{compounds},"\t","|",0,["ID"]);
	}
	$self->figmodel()->import_biochem({
		figmodel => $self->figmodel(),
		compounds => $cpdtbl,
		reactions => $rxntbl,
		reactionstart => $args->{rxnstart},
		compoundstart => $args->{cpdstart}
	});
	return "SUCCESS";
}
=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This function is used to add a minimal number of reactions to a model from the biochemistry database such that one or more inactive reactions is eliminated.
=EXAMPLE
./mdlautocomplete '''-model''' iJR904"
=cut
sub mdlautocomplete {
    my($self,@Data) = @_;
    my $args = $self->check([
		["model",1,undef,"The full Model SEED ID of the model to be gapfilled."],
		["media",0,"Complete","The media condition the model will be gapfilled in."],
		["removegapfilling",0,1,"All existing gapfilled reactions in the model will be deleted prior to the new gapfilling if this flag is set to '1'."],
		["inactivecoef",0,0,"The coefficient on the inactive reactions in the gapfilling objective function."],
		["adddrains",0,0,"Drain fluxes will be added for all intracellular metabolites and minimized if this flag is set to '1'."],
		["iterative",0,0,"All inactive reactions in the model will be identified, and they will be iteratively gapfilled one at a time if this flag is set to '1'."],
		["testsolution",0,0,"Set this FLAG to '1' in order to test the gapfilling solution to assess the reason for addition of each gapfilled solution."],
		["printdbmessage",0,0,"Set this FLAG to '1' in order to print a message about gapfilling results to the database."],
		["coefficientfile",0,undef,"Name of a flat file specifying coefficients for gapfilled reactions in objective function."],
		["rungapfilling",0,1,"The gapfilling will not be run unless you set this flag to '1'."],
		["problemdirectory",0,undef, "The name of the job directory where the intermediate gapfilling output will be stored."],
		["startfresh",0,1,"Any files from previous gapfilling runs in the same output directory will be deleted if this flag is set to '1'."],
	],[@Data],"adds reactions to the model to eliminate inactive reactions");
    $args->{media} =~ s/\_/ /g;
    #Getting model list
    my $models = ModelSEED::Interface::interface::PROCESSIDLIST({
		objectType => "model",
		delimiter => ";",
		column => "id",
		parameters => {},
		input => $args->{model}
	});
	#If more than one model was specified, we queue up gapfilling for each model
	if (@{$models} > 1 || $args->{queue} == 1) {
	    for (my $i=0; $i < @{$models}; $i++) {
	    	$args->{model} = $models->[$i]->id();
	    	$self->figmodel()->queue()->queueJob({
				function => "mdlautocomplete",
				arguments => $args,
			});
		}
	}
	#If only one model was selected, we run gapfilling
   	my $model = $self->figmodel()->get_model($models->[0]);
   	if (!defined($model)) {
   		ModelSEED::utilities::ERROR("Model ".$models->[0]." not found in database!");
   	}
   	$model->completeGapfilling({
		startFresh => $args->{startfresh},
		problemDirectory => $args->{problemdirectory},
		rungapfilling=> $args->{rungapfilling},
		removeGapfillingFromModel => $args->{removegapfilling},
		gapfillCoefficientsFile => $args->{coefficientfile},
		inactiveReactionBonus => $args->{inactivecoef},
		fbaStartParameters => {
			media => $args->{"media"}
		},
		iterative => $args->{iterative},
		adddrains => $args->{adddrains},
		testsolution => $args->{testsolution},
		globalmessage => $args->{printdbmessage}
	});
    return "Successfully gapfilled model ".$models->[0]." in ".$args->{media}." media!";
}
=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This function is used to compare the reactions associated with a list of input models
=EXAMPLE
./mdlcomparemodels
=cut
sub mdlcomparemodels {
    my($self,@Data) = @_;
    my $args = $self->check([
		["modellist",1,undef,"List of models you want to compare."],
		["saveformat",0,"EXCEL"]
	],[@Data],"compare the reactions associated with input models");
    my $models = ModelSEED::Interface::interface::PROCESSIDLIST({
		objectType => "model",
		delimiter => ";",
		column => "id",
		parameters => {},
		input => $args->{modellist}
	});
	my $output = $self->figmodel()->compareModels({modellist => $models});
	my $extension = ".xls";
	if (defined($output->{"reaction comparison"})) {
		if ($args->{saveformat} eq "EXCEL") {
			$self->figmodel()->make_xls({
				filename => $self->ws()->directory()."Comparison.xls",
				sheetnames => ["Reaction comparison"],
				sheetdata => [$output->{"reaction comparison"}]
			});
		} elsif ($args->{saveformat} eq "TEXT") {
			$extension = ".tbl";
			$output->{"reaction comparison"}->save($self->ws()->directory()."Comparison.tbl");
		}
	}
	return "Successfully completed model comparison. Results printed in ".$self->ws()->directory()."Comparison".$extension;
}
=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This command uses the Model SEED pipeline to reconstruct an existing SEED model from scratch based on SEED genome annotations.
=EXAMPLE
./mdlreconstruction -model Seed83333.1
=cut
sub mdlreconstruction {
    my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"The name of an existing model in the Model SEED database that should be reconstructed from scratch from genome annotations."],
		["autocompletion",0,0,"Set this FLAG to '1' in order to run the autocompletion process immediately after the reconstruction is complete."],
		["checkpoint",0,0,"Set this FLAG to '1' in order to check in the model prior to the reconstruction process so the current model will be preserved."],
	],[@Data],"run model reconstruction from genome annotations");
    my $mdl =  $self->figmodel()->get_model($args->{"model"});
    if (!defined($mdl)) {
    	ModelSEED::utilities::ERROR("Model not valid ".$args->{model});
    }
    $mdl->reconstruction({
    	checkpoint => $args->{"checkpoint"},
		autocompletion => $args->{"autocompletion"},
	});
    return "Generated model from genome annotations";
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This function creates a model that includes all reactions in the current database. Such a model is useful to determine the capabilities of the current biochemistry database.
=EXAMPLE
./mdlmakedbmodel -model ModelSEED
=cut
sub mdlmakedbmodel {
    my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"The name of the model that will contain all the database reactions."],
	],[@Data],"construct a model with all database reactions");
    my $mdl =  $self->figmodel()->get_model($args->{"model"});
    if (!defined($mdl)) {
    	ModelSEED::utilities::ERROR("Model not valid ".$args->{model});
    }
    $mdl->generate_fulldb_model();
	return "Set model reaction list to entire biochemistry database";
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This function is used to provide rights to view or edit a model to another Model SEED user. Use this function to share a model.
=EXAMPLE
./mdladdright -model Seed83333.1.796 -user reviewer -right view
=cut
sub mdladdright {
	my($self,@Data) = @_;
    my $args = $self->check([
		["model",1,undef,"ID of the model for which rights should be added."],
		["user",1,undef,"Login of the user account for which rights should be added."],
		["right",0,"view","Type of right that should be added. Possibilities include 'view' and 'admin'."]
	],[@Data],"add rights to a model to another user");
    my $mdl =  $self->figmodel()->get_model($args->{"model"});
    if (!defined($mdl)) {
    	ModelSEED::utilities::ERROR("Model not valid ".$args->{model});
    }
    $mdl->changeRight({
    	permission => $args->{right},
		username => $args->{user},
		force => 1
    });
	return "Successfully added ".$args->{right}." rights for user ".$args->{user}." to model ".$args->{model}."!\n";	
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This function is used to create new models in the Model SEED database.
=EXAMPLE
./mdlcreatemodel -genome 83333.1
=cut
sub mdlcreatemodel {
    my($self,@Data) = @_;
	my $args = $self->check([
		["genome",1,undef,"A ',' delimited list of genomes for which new models should be created."],
		["id",0,undef,"ID that the new model should have in the Model SEED database."],
		["biomass",0,undef,"ID of the biomass reaction the new model should have in the Model SEED database."],
		["owner",0,ModelSEED::Interface::interface::USERNAME(),"The login of the user account that should own the new model."],
		["biochemSource",0,undef,"Path to an existing biochemistry provenance database that should be used for provenance in the new model."],
		["reconstruction",0,1,"Set this FLAG to '1' to autoatically run the reconstruction algorithm on the new model as soon as it is created."],
		["autocompletion",0,0,"Set this FLAG to '1' to autoatically run the autocompletion algorithm on the new model as soon as it is created."],
		["overwrite",0,0,"Set this FLAG to '1' to overwrite any model that has the same specified ID in the database."],
	],[@Data],"create new Model SEED models");    
    my $output = ModelSEED::Interface::interface::PROCESSIDLIST({
		objectType => "genome",
		delimiter => ",",
		input => $args->{genome}
	});
	my $message = "";
    if (@{$output} == 1 || $args->{usequeue} eq 0) {
    	for (my $i=0; $i < @{$output}; $i++) {
    		my $mdl = $self->figmodel()->create_model({
				genome => $output->[0],
				id => $args->{id},
				owner => $args->{owner},
				biochemSource => $args->{"biochemSource"},
				biomassReaction => $args->{"biomass"},
				reconstruction => $args->{"reconstruction"},
				autocompletion => $args->{"autocompletion"},
				overwrite => $args->{"overwrite"}
			});
			if (defined($mdl)) {
				$message .= "Successfully created model ".$mdl->id()."!\n";
			} else {
				$message .= "Failed to create model ".$mdl->id()."!\n";
			}
    	}
	} else {
		for (my $i=0; $i < @{$output}; $i++) {
	    	$args->{model} = $output->[$i];
	    	$self->figmodel()->queue()->queueJob({
				function => "mdlcreatemodel",
				arguments => $args,
				user => ModelSEED::Interface::interface::USERNAME()
			});
    	}
	}
    return $message;
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
Inspects that the specified model(s) are consistent with their associated biochemistry databases", and modifies the database if not.
=EXAMPLE
./mdlinspectstate -model iJR904
=cut
sub mdlinspectstate {
    my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"A ',' delimited list of the models in the Model SEED that should be inspected."],
	],[@Data],"inspect that model consistency with biochemistry database");
	my $results = ModelSEED::Interface::interface::PROCESSIDLIST({
		objectType => "model",
		delimiter => ",",
		column => "id",
		parameters => {},
		input => $args->{"model"}
	});
	if (@{$results} == 1 || $args->{usequeue} == 0) {
		for (my $i=0;$i < @{$results}; $i++) {
			my $mdl = $self->figmodel()->get_model($results->[$i]);
	 		if (!defined($mdl)) {
	 			ModelSEED::utilities::WARNING("Model not valid ".$results->[$i]);	
	 		} else {
	 			$mdl->InspectModelState({});
	 		}
		}
	} else {
		for (my $i=0; $i < @{$results}; $i++) {
			$args->{model} = $results->[$i];
			$self->figmodel()->queue()->queueJob({
				function => "mdlinspectstate",
				arguments => $args
			});
		}
	}
    return "SUCCESS";
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
Prints the specified model(s) in SBML format.
=EXAMPLE
./mdlprintsbml -model iJR904
=cut
sub mdlprintsbml {
    my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"Model for which SBML files should be printed."],
		["media",0,"Complete","ID of a media condition or media file for which SBML should be printed"],
	],[@Data],"prints model(s) in SBML format");
	my $models = ModelSEED::Interface::interface::PROCESSIDLIST({
		objectType => "model",
		delimiter => ";",
		column => "id",
		parameters => {},
		input => $args->{"model"}
	});
	if ($args->{media} =~ m/\.media$/) {
		if (!-e $self->ws()->directory().$args->{media}) {
			ModelSEED::utilities::ERROR("Media file ".$self->ws()->directory().$args->{media}." not found");
		}
		$args->{media} = ModelSEED::MooseDB::media->new({
			filename => $args->{media}
		});
	}
	my $message;
	for (my $i=0; $i < @{$models};$i++) {
		print "Now loading model ".$models->[$i]."\n";
		my $mdl = $self->figmodel()->get_model($models->[$i]);
		if (!defined($mdl)) {
	 		ModelSEED::utilities::WARNING("Model not valid ".$args->{model});
	 		$message .= "SBML printing failed for model ".$models->[$i].". Model not valid!\n";
	 		next;
	 	}
	 	my $sbml = $mdl->PrintSBMLFile({
	 		media => $args->{media}
	 	});
		ModelSEED::utilities::PRINTFILE($self->ws()->directory().$models->[$i].".xml",$sbml);
		$message .= "SBML printing succeeded for model ".$models->[$i]."!\nFile printed to ".$self->ws()->directory().$models->[$i].".xml"."!";
	}
    return $message;
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This is a useful function for printing model data to simple flatfiles that may be easily altered to facilitate hand-curation of a model. The function accepts a model ID as input, and it creates two flat files for the specified model: 
* a reaction table file that lists the id, directionality,
* a biomass reaction file that lists the equation of the biomass reaction
By default, the flatfiles are printed in the "Model-SEED-core/data/MSModelFiles/" directory, but you can specify where the files will be printed using the "filename" and "biomassFilename" input arguments.
NOTE: currently this function is the only mechanism for moving models from the Central Model SEED database into a local Model SEED database. This will soon change.
=EXAMPLE
./mdlprintmodel -'''model''' "iJR904"
=cut
sub mdlprintmodel {
	my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"The full Model SEED ID of the model to be printed."],
		["filename",0,undef,"The full path and name of the file where the model reaction table should be printed."],
		["biomassFilename",0,undef,"The full path and name of the file where the biomass reaction should be printed."]
	],[@Data],"prints a model to flatfile for alteration and reloading");
	my $mdl = $self->figmodel()->get_model($args->{model});
	if (!defined($mdl)) {
		ModelSEED::utilities::ERROR("Model not valid ".$args->{model});
	}
	if (!defined($args->{filename})) {
		$args->{filename} = $self->figmodel()->ws()->directory().$args->{model}.".mdl";
	}
    my $biomass = $mdl->biomassReaction();
	if( defined($biomass) && $biomass ne "NONE"){
	    if (!defined($args->{biomassFilename})){
			$args->{biomassFilename} = $self->figmodel()->ws()->directory().$biomass.".bof";
	    }
	    $self->figmodel()->get_reaction($biomass)->print_file_from_ppo({
			filename => $args->{biomassFilename}
	    });
	}
	$mdl->printModelFileForMFAToolkit({
		filename => $args->{filename}
	});
	return "Successfully printed data for ".$args->{model}." in files:\n".$args->{filename}."\n".$args->{biomassFilename}."\n\n";
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This is a useful function for printing model data to the flatfiles that are used by CytoSEED. The function accepts a model ID as input, and it creates a directory using the model id that contains model data in the format expected by CytoSEED.
By default, the model is printed in the "Model-SEED-core/data/MSModelFiles/" directory, but you can specify where the model will be printed using the "directory" input argument. You should print or copy the model data to the CytoSEED/Models folder (see "Set Location of CytoSEED Folder" menu item under "Plugins->SEED" in Cytoscape).
=EXAMPLE
./mdlprintcytoseed -'''model''' "iJR904" -'''directory''' "/Users/dejongh/Desktop/CytoSEED/Models"
=cut
sub mdlprintcytoseed {
	my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"The full Model SEED ID of the model to be printed."],
		["directory",0,undef,"The full path and name of the directory where the model should be printed."],
	],[@Data],"prints a model to format expected by CytoSEED");
	my $mdl = $self->figmodel()->get_model($args->{model});
	if (!defined($mdl)) {
		ModelSEED::utilities::ERROR("Model not valid ".$args->{model});
	}
	if (!defined($args->{directory})) {
		$args->{directory} = $self->figmodel()->ws()->directory();
	}
	my $cmdir = $args->{directory}."/".$args->{model};
	if (! -e $cmdir) {
	    mkdir($cmdir) or ModelSEED::utilities::ERROR("Could not create $cmdir: $!\n");
	}
	my $fbaObj = ModelSEED::ServerBackends::FBAMODEL->new();
	my $dumper = YAML::Dumper->new;

	open(FH, ">".$cmdir."/model_data") or ModelSEED::utilities::ERROR("Could not open file: $!\n");
	my $md = $fbaObj->get_model_data({ "id" => [$args->{model}] });
	print FH $dumper->dump($md->{$args->{model}});
	close FH;
	print "Model data printed...\n";
	open(FH, ">".$cmdir."/biomass_reaction_details") or ModelSEED::utilities::ERROR("Could not open file: $!\n");
	print FH $dumper->dump($fbaObj->get_biomass_reaction_data({ "model" => [$args->{model}] }));
	close FH;
	print "Biomass data printed...\n";
	my $cids = $fbaObj->get_compound_id_list({ "id" => [$args->{model}] });
	open(FH, ">".$cmdir."/compound_details") or ModelSEED::utilities::ERROR("Could not open file: $!\n");
	my $cpds = $fbaObj->get_compound_data({ "id" => $cids->{$args->{model}} });
	print FH $dumper->dump($cpds);
	close FH;
	print "Compound data printed...\n";
	my @abcids;
	foreach (keys %$cpds) { 
	    if (defined $cpds->{$_}->{"ABSTRACT COMPOUND"}->[0] && 
		$cpds->{$_}->{"ABSTRACT COMPOUND"}->[0] ne "none") {
		push @abcids, $cpds->{$_}->{"ABSTRACT COMPOUND"}->[0];
	    }
	}
	open(FH, ">".$cmdir."/abstract_compound_details") or ModelSEED::utilities::ERROR("Could not open file: $!\n");
	print FH $dumper->dump($fbaObj->get_compound_data({ "id" => \@abcids }));
	close FH;
	print "Abstract compound data printed...\n";
	my $rids = $fbaObj->get_reaction_id_list({ "id" => [$args->{model}] });
	open(FH, ">".$cmdir."/reaction_details") or ModelSEED::utilities::ERROR("Could not open file: $!\n");
	my $rxns = $fbaObj->get_reaction_data({ "id" => $rids->{$args->{model}}, "model" => [$args->{model}] });
	print FH $dumper->dump($rxns);
	close FH;
	print "Reaction data printed...\n";
	my @abrids = map { exists $rxns->{$_}->{"ABSTRACT REACTION"} ? $rxns->{$_}->{"ABSTRACT REACTION"}->[0] : undef } keys %$rxns;
	open(FH, ">".$cmdir."/abstract_reaction_details") or ModelSEED::utilities::ERROR("Could not open file: $!\n");
	print FH $dumper->dump($fbaObj->get_reaction_data({ "id" => \@abrids, "model" => [$args->{model}] }));
	close FH;
	print "Abstract reaction data printed...\n";
	open(FH, ">".$cmdir."/reaction_classifications") or ModelSEED::utilities::ERROR("Could not open file: $!\n");
	print FH $dumper->dump($fbaObj->get_model_reaction_classification_table({ "model" => [$args->{model}] }));
	close FH;
	print "Reaction class data printed...\n";
	return "Successfully printed cytoseed data for ".$args->{model}." in directory:\n".$args->{directory}."\n";
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This function prints a list of all genes included in the specified model to a file in the workspace.
=EXAMPLE
./mdlprintmodelgenes -model iJR904
=cut
sub mdlprintmodelgenes {
	my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"Name of the model for which the genes should be printed."],
		["filename",0,undef,"Name of the file in the current workspace where the genes should be printed."]
	],[@Data],"print all genes in model");
	my $mdl = $self->figmodel()->get_model($args->{model});
	if (!defined($mdl)) {
		ModelSEED::utilities::ERROR("Model not valid ".$args->{model});
	}
	if (!defined($args->{filename})) {
		$args->{filename} = $mdl->id()."-GeneList.lst";
	}
	my $ftrHash = $mdl->featureHash();
	my $output = ["Genes\tReactions"];
	foreach my $ftr (keys(%{$ftrHash})) {
		push(@{$output},$ftr."\t".join(",",keys(%{$ftrHash->{$ftr}->{reactions}})));	
	}
	ModelSEED::utilities::PRINTFILE($self->ws()->directory().$args->{filename},$output);
	return "Successfully printed genelist for ".$args->{model}." in ".$self->ws()->directory().$args->{filename}."!\n";
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This function is used to load a model reaction table and biomass reaction back into a Model SEED database. At least the model base ID and genome ID must be provided. If no filenames are provided, the system assumes the files are located in the following locations:
* Model reaction table: Model-SEED-core/data/MSModelFiles/''Model ID''.tbl [[Example model file]]
* Biomass reaction file: Model-SEED-core/data/MSModelFiles/''Model Biomass reaction ID''.txt [[Example biomass file]]
This function is designed to be used in conjunction with ''printmodelfiles'' to print model data to flatfiles, allow hand-curation of these flatfiles, and then load model data back into the Model SEED from these flatfiles.
=EXAMPLE
./mdlloadmodel -'''name''' "iJR904" -'''genome''' "83333.1"
=cut
sub mdlloadmodel {
	my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"The base name of the model to be loaded (do not append your user index, the Model SEED will automatically do this for you)."],
    	["genome",0,undef,"The SEED genome ID associated with the model to be loaded."],
    	["generateprovenance",0,1,"Regenerate provenance from the database"],
    	["filename",0,undef,"The full path and name of the file where the reaction table for the model to be imported is located. [[Example model file]]."],
    	["biomassFile",0,undef,"The full path and name of the file where the biomass reaction for the model to be imported is located. [[Example biomass file]]."],
    	["owner",0,ModelSEED::Interface::interface::USERNAME(),"The login name of the user that should own the loaded model"],
    	["provenance",0,undef,"The full path to a model directory that contains a provenance database for the model to be imported. If not provided, the Model SEED will generate a new provenance database from scratch using current system data."],
    	["overwrite",0,0,"If you are attempting to load a model that already exists in the database, you MUST set this argument to '1'."],
    	["public",0,0,"If you want the loaded model to be publicly viewable to all Model SEED users, you MUST set this argument to '1'."],
    	["autoCompleteMedia",0,"Complete","Name of the media used for auto-completing this model."]
	],[@Data],"reload a model from a flatfile");
	if (!defined($args->{filename})) {
		$args->{filename} = $self->ws()->directory().$args->{model}.".mdl";
	}
	if (!-e $args->{filename}) {
		ModelSEED::utilities::USEERROR("Model file ".$args->{filename}." not found. Check file and input.");
	}
	$args->{modelfiledata} = ModelSEED::utilities::LOADFILE($args->{filename});
	if (!defined($args->{biomassFile})) {
		my $biomassID;
		for (my $i=0; $i < @{$args->{modelfiledata}};$i++) {
			if ($args->{modelfiledata}->[$i] =~ m/^(bio\d+);/) {
				$biomassID = $1;
			}
		}
		$args->{biomassFile} = $self->ws()->directory().$biomassID.".bof";
	}
	if (-e $args->{biomassFile}) {
		my $obj = ModelSEED::FIGMODEL::FIGMODELObject->new({filename=>$args->{biomassFile},delimiter=>"\t",-load => 1});
		$args->{biomassEquation} = $obj->{EQUATION}->[0];
		$args->{biomassid} = $obj->{DATABASE}->[0];
	}
	my $modelObj = $self->figmodel()->import_model_file({
		modelfiledata => $args->{modelfiledata},
		id => $args->{model},
		genome => $args->{genome},
		biomassID => $args->{biomassid},
		biomassEquation => $args->{biomassEquation},
		owner => $args->{owner},
		public => $args->{public},
		overwrite => $args->{overwrite},
		biochemSource => $args->{provenance},
		autoCompleteMedia => $args->{autoCompleteMedia},
		generateprovenance => $args->{generateprovenance}
	});
	print "Successfully imported ".$args->{model}." into Model SEED as ".$modelObj->id()."!\n\n";
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This function changes the drain fluxes associated with a model.
=EXAMPLE
./mdlchangedrains -'''model''' "iJR904" -'''drains''' "cpd15302[c]" -'''inputs''' "cpd15302[c]"
=cut
sub mdlchangedrains {
	my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"ID of the model the drains are to be added to"],
    	["drains",0,undef,"\";\" delimited list of compounds for which drains should be added"],
    	["inputs",0,undef,"\";\" delimited list of compounds for which inputs should be added"],
	],[@Data],"change drain fluxes associated with model");
	if (defined($args->{drains})) {
		$args->{drains} = ModelSEED::globals::PROCESSIDLIST({
			input => $args->{drains},
			validation => "^cpd\\d+\\[*\\w*\\]*\$"
		});
	}
	if (defined($args->{inputs})) {
		$args->{inputs} = ModelSEED::globals::PROCESSIDLIST({
			input => $args->{inputs},
			validation => "^cpd\\d+\\[*\\w*\\]*\$"
		});
	}
	my $model = $self->figmodel()->get_model($args->{model});
	if (!defined($model)) {
		ModelSEED::utilities::ERROR("Model not valid ".$args->{model});
	}
	my $string = $model->changeDrains({
		drains => $args->{drains},
		inputs => $args->{inputs},
	});
	return "Successfully adjusted the drain fluxes associated with model ".$args->{model}." to ".$string;
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This function creates (or alters) a biomass reaction in the Model SEED database given an input file or biomass ID that points to an input file.
=EXAMPLE
./mdlloadbiomass -'''biomass''' bio00001
=cut
sub mdlloadbiomass {
	my($self,@Data) = @_;
	my $args = $self->check([
		["biomass",1,undef,"The ID (e.g. bio00001) or filename of the biomass reaction to be loaded. If only an ID is specified, either the '''equation''' argument must also be set, or the ''Biomass ID''.txt file must exist. [[Example biomass file]]"],
    	["model",0,undef,"The name of the FBA model the biomass reaction will be added to."],
    	["equation",0,undef,"The stoichiometric equation for the biomass reaction."],
    	["overwrite",0,0,"If you are attempting to alter and existing biomass reaction, you MUST set this argument to '1'"]
	],[@Data],"Loads a model biomass reaction into the database from a flatfile");
	#Load the file if no equation was specified
	if (!defined($args->{equation})) {
		#Setting the filename if only an ID was specified
		my $filename = $args->{biomass};
		if ($filename =~ m/^bio\d+$/) {
			$filename = $self->figmodel()->ws()->directory().$args->{biomass}.".bof";
		}
		#Loading the biomass reaction
		ModelSEED::utilities::ERROR("Could not find specified biomass file ".$filename."!") if (!-e $filename);
		#Loading biomass reaction file
		my $obj = ModelSEED::FIGMODEL::FIGMODELObject->new({filename=>$filename,delimiter=>"\t",-load => 1});
		$args->{equation} = $obj->{EQUATION}->[0];
		if ($args->{biomass} =~ m/(^bio\d+)/) {
			$obj->{DATABASE}->[0] = $1;
		}
		$args->{biomass} = $obj->{DATABASE}->[0];
	}
	#Loading the biomass into the database
	my $bio = $self->db()->get_object("bof",{id => $args->{biomass}});
	if (defined($bio) && $args->{overwrite} == 0 && !defined($args->{model})) {
	  ModelSEED::utilities::ERROR("Biomass ".$args->{biomass}." already exists, and you did not pass a model id, You must therefore specify an overwrite!");
	}
	
	my $msg="";
	if(!defined($bio) || $args->{overwrite} == 1){
	    my $bofobj = $self->figmodel()->get_reaction()->add_biomass_reaction_from_equation({
		equation => $args->{equation},
		biomassID => $args->{biomass}
	       });
	    my $msg = "Successfully loaded biomass reaction ".$args->{biomass}.".\n"; 
	}

	#Adjusting the model if a model was specified
	if (defined($args->{model})) {
		my $mdl = $self->figmodel()->get_model($args->{model});
		ModelSEED::utilities::ERROR("Model ".$args->{model}." not found in database!") if (!defined($mdl));
		$mdl->biomassReaction($args->{biomass});
		$msg .= "Successfully changed biomass reaction in model ".$args->{model}.".\n";
	}
	return $msg;
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This function parses the input SBML file into compound and reaction tables needed for import into the Model SEED.
=EXAMPLE
./mdlparsesbml -file iJR904.sbml
=cut
sub mdlparsesbml {
	my($self,@Data) = @_;
	my $args = $self->check([
		["file",1,undef,"The name of the SBML file to be parsed. It is assumed the file is present in the workspace."]
	],[@Data],"parsing SBML file into compound and reaction tables");
	my $List = $self->figmodel()->parseSBMLToTable({file => $self->ws()->directory().$args->{file}});
	foreach my $table(keys %$List){
		$List->{$table}->save();
	}
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
Imports a models from other databases into the Model SEED environment.
=EXAMPLE
./mdlimportmodel -name iJR904 -genome 83333.1
=cut
sub mdlimportmodel {
    my($self,@Data) = @_;
    my $args = $self->check([
    	["name",1,undef,"The ID in the Model SEED that the imported model should have, or the ID of the model to be overwritten by the imported model."],
    	["genome",0,"NONE","SEED ID of the genome the imported model should be associated with."],
    	["owner",0,ModelSEED::Interface::interface::USERNAME(),"Name of the user account that will own the imported model."],
    	["path",0,$self->ws()->directory(),"The path where the compound and reaction files containing the model data to be imported are located."],
    	["overwrite",0,0,"Set this FLAG to '1' to overwrite an existing model with the same name."],
    	["biochemsource",0,undef,"The path to the directory where the biochemistry database that the model should be imported into is located."]
    ],[@Data],"import a model into the Model SEED environment");
	if (!-e $args->{path}.$args->{name}."-reactions.tbl") {
		ModelSEED::utilities::USEERROR("Could not find import file:".$args->{path}.$args->{name}."-reactions.tbl");
	}
	if (!-e $args->{path}.$args->{name}."-compounds.tbl") {
		ModelSEED::utilities::USEERROR("Could not find import file:".$args->{path}.$args->{name}."-compounds.tbl");
	}
	$args->{reactionTable} = ModelSEED::FIGMODEL::FIGMODELTable::load_table($args->{path}.$args->{name}."-reactions.tbl","\t","|",0,["ID"]);
	$args->{compoundTable} = ModelSEED::FIGMODEL::FIGMODELTable::load_table($args->{path}.$args->{name}."-compounds.tbl","\t","|",0,["ID"]);
	my $public = 0;
	if ($args->{"owner"} eq "master") {
		$public = 1;
	}
	$self->figmodel()->import_model({
		baseid => $args->{"name"},
		compoundTable => $args->{compoundTable},
		reactionTable => $args->{reactionTable},
		genome => $args->{"genome"},
		owner => $args->{"owner"},
		public => $public,
		overwrite => $args->{"overwrite"},
		biochemSource => $args->{"biochemsource"}
	});
	return "SUCCESS";
}

=head
=CATEGORY
Utility Functions
=DESCRIPTION
This function loads a table of numerical data from your workspace and determines how the data values are distributed into bins.
=EXAMPLE
./utilmatrixdist -matrix [[MyData.tbl]] -binsize 1
=cut
sub utilmatrixdist {
    my($self,@Data) = @_;
    my $args = $self->check([
		["matrixfile",1,undef,"Filename of table with numerical data you want to calculate the distribution of. Unless a full path is specified, file is assumed to be located in the current workspace."],
		["binsize",0,1,"Size of bins into which data should be distributed."],
		["startcol",0,1,"Column of the input data table where the numerical data begins."],
		["endcol",0,undef,"Column of the input data table where the numerical data ends.","Defaults to the number of columns in the input file."],
		["startrow",0,1,"Row of the input data table where the numerical data begins."],
		["endrow",0,undef,"Row of the input data table where the numerical data ends.","Defaults to the number of rows in the input file."],
		["delimiter",0,"\\t","Delimiter used in the input data table."]
	],[@Data],"binning numerical matrix data into a histogram");
    #Checking that file exists
    if (!-e $self->ws()->directory().$args->{matrixfile}) {
    	ModelSEED::utilities::ERROR("Could not find matrix file ".$self->ws()->directory().$args->{matrixfile}."!");
    }
    #Loading the file
    print "Loading...\n";
    my $distribData;
    my $data = ModelSEED::utilities::LOADFILE($self->ws()->directory().$args->{matrixfile});
    if (!defined($args->{endrow})) {
    	$args->{endrow} = @{$data};
    }
    print "Calculating...\n";
    #Calculating the distribution for each row as well as the overall distribution
    my $moreRowData;
    for (my $i=$args->{startrow}; $i < $args->{endrow}; $i++) {
    	my $rowData = [split($args->{delimiter},$data->[$i])];
    	$moreRowData->{$rowData->[0]} = {
    		zeros => 0,
    		average => 0,
    		stddev => 0,
    		instances => 0,
    		maximum => 0
    	};
    	print "Processing row ".$i.":".$rowData->[0]."\n";
    	if (!defined($args->{endcol})) {
	    	$args->{endcol} = @{$rowData};
	    }
    	for (my $j=$args->{startcol}; $j < $args->{endcol}; $j++) {
    		if ($rowData->[$j] =~ m/^\d+\.*\d*$/) {
    			if ($rowData->[$j] > $moreRowData->{$rowData->[0]}->{maximum}) {
    				$moreRowData->{$rowData->[0]}->{maximum} = $rowData->[$j];
    			}
    			if ($rowData->[$j] == 0) {
    				$moreRowData->{$rowData->[0]}->{zeros}++;
    			}
    			$moreRowData->{$rowData->[0]}->{average} += $rowData->[$j];
    			$moreRowData->{$rowData->[0]}->{instances}++;
    			my $bin = ModelSEED::FIGMODEL::floor($rowData->[$j]/$args->{binsize});
    			if (!defined($distribData->{$rowData->[0]}->[$bin])) {
    				$distribData->{$rowData->[0]}->[$bin] = 0;
    			}
    			$distribData->{$rowData->[0]}->[$bin]++;
    			if (!defined($distribData->{"total"}->[$bin])) {
    				$distribData->{"total"}->[$bin] = 0;
    			}
    			$distribData->{"total"}->[$bin]++;
    		}
    	}
    	if ($moreRowData->{$rowData->[0]}->{instances} != 0) {
    		$moreRowData->{$rowData->[0]}->{average} = $moreRowData->{$rowData->[0]}->{average}/$moreRowData->{$rowData->[0]}->{instances};
    	}
    	for (my $j=$args->{startcol}; $j < $args->{endcol}; $j++) {
    		if ($rowData->[$j] =~ m/^\d+\.*\d*$/) {
    			$moreRowData->{$rowData->[0]}->{stddev} += ($rowData->[$j]-$moreRowData->{$rowData->[0]}->{average})*($rowData->[$j]-$moreRowData->{$rowData->[0]}->{average});		
    		}
    	}
    	if ($moreRowData->{$rowData->[0]}->{instances} != 0) {
    		$moreRowData->{$rowData->[0]}->{stddev} = sqrt($moreRowData->{$rowData->[0]}->{stddev}/$moreRowData->{$rowData->[0]}->{instances});
    	}
    	delete $data->[$i];
    }
    #Normalizing distrubtions
    my $largestBin = 0;
    my $normDistribData;
    print "Normalizing\n";
    foreach my $label (keys(%{$distribData})) {
    	if (@{$distribData->{$label}} > $largestBin) {
    		$largestBin = @{$distribData->{$label}};
    	}
    	my $total = 0;
    	for (my $j=0; $j < @{$distribData->{$label}}; $j++) {
    		if (defined($distribData->{$label}->[$j])) {
    			$total += $distribData->{$label}->[$j];
    		}
    	}
    	for (my $j=0; $j < @{$distribData->{$label}}; $j++) {
    		if (defined($distribData->{$label}->[$j])) {
    			$normDistribData->{$label}->[$j] = $distribData->{$label}->[$j]/$total;
    		}
    	}
    }
    #Printing distributions
    print "Printing...\n";
    my $bins = [];
    for (my $i=0; $i < $largestBin; $i++) {
    	$bins->[$i] = $i*$args->{binsize}."-".($i+1)*$args->{binsize};
    }
    my $fileData = {
    	"Distributions.txt" => ["Label\tZeros\tAverage\tStdDev\tInstances\tMaximum\t".join("\t",@{$bins})],
    	"NormDistributions.txt" => ["Label\tZeros\tAverage\tStdDev\tInstances\tMaximum\t".join("\t",@{$bins})]
    };
    foreach my $label (keys(%{$distribData})) {
		my $line = $label."\t".$moreRowData->{$label}->{zeros}."\t".$moreRowData->{$label}->{average}."\t".$moreRowData->{$label}->{stddev}."\t".$moreRowData->{$label}->{instances}."\t".$moreRowData->{$label}->{maximum};
		my $normline = $label."\t".$moreRowData->{$label}->{zeros}."\t".$moreRowData->{$label}->{average}."\t".$moreRowData->{$label}->{stddev}."\t".$moreRowData->{$label}->{instances}."\t".$moreRowData->{$label}->{maximum};
		for (my $j=0; $j < $largestBin; $j++) {
    		if (defined($distribData->{$label}->[$j])) {
    			$line .= "\t".$distribData->{$label}->[$j];
    			$normline .= "\t".$normDistribData->{$label}->[$j];
    		} else {
    			$line .= "\t0";
    			$normline .= "\t0";
    		}
    	}
		push(@{$fileData->{"Distributions.txt"}},$line);
		push(@{$fileData->{"NormDistributions.txt"}},$normline);
	}
	my $message = "";
	foreach my $filename (keys(%{$fileData})) {
		ModelSEED::utilities::PRINTFILE($self->ws()->directory().$filename,$fileData->{$filename});
		$message .= "Printed distributions to ".$self->ws()->directory().$filename."\n";
	}
	return $message;
}

=head
=CATEGORY
Temporary
=DESCRIPTION
=EXAMPLE
=cut
sub coordtogenes {
    my($self,@Data) = @_;
    my $args = $self->check([
    	["filename",1,undef,"Filename"]
    ],[@Data],"coordtogenes");
	my $data = ModelSEED::utilities::LOADFILE($self->ws()->directory().$args->{filename});
	my $genes;
	my $mdl = $self->figmodel()->get_model("iBsuNew.796");
	my $features = $mdl->provenanceFeatureTable();
	for (my $i=1; $i < @{$data}; $i++) {
		my $array = [split(/\t/,$data->[$i])];
		my $geneList;
		for (my $j=0; $j < $features->size(); $j++) {
			my $row = $features->get_row($j);
			if ($row->{"MIN LOCATION"}->[0] < $array->[1]) {
				if ($row->{"MAX LOCATION"}->[0] > $array->[0]) {
					if ($row->{ID}->[0] =~ m/(peg\.\d+)/) {
						push(@{$geneList},$1);
					}	
				}
			}
		}
		push(@{$genes},join(",",@{$geneList}));
	}
	ModelSEED::utilities::PRINTFILE($self->ws()->directory()."GeneList.lst",$genes);
	return "SUCCESS";
}

=head
=CATEGORY
Genome Operations
=DESCRIPTION
Classifying the type of respiration of a genome based on the functions present
=EXAMPLE
=cut
sub genclassifyrespiration {
    my($self,@Data) = @_;
	my $args = $self->check([
		["genome",1,undef,"SEED ID of the genome to be analyzed"]
	],[@Data],"classifying the type of respiration of a genome based on the functions present");
	my $genomeObj = $self->figmodel()->get_genome($args->{genome});
	return $genomeObj->classifyrespiration();
}

=head
=CATEGORY
Genome Operations
=DESCRIPTION
Classifying the type of respiration of a genome based on the functions present
=EXAMPLE
=cut
sub genlistsubsystemgenes {
    my($self,@Data) = @_;
	my $args = $self->check([
		["genome",1,undef,"SEED ID of the genome to be analyzed"],
		["subsystem",1,undef,"Subsystem for which genes should be listed"]
	],[@Data],"classifying the type of respiration of a genome based on the functions present");
	my $sap = $self->figmodel()->sapSvr($args->{source});
	my $subsys = $sap->ids_in_subsystems({
		-subsystems => [$args-> {subsystem}],
		-genome => $args -> {genome},
		-roleForm => "full",
	});
	print Data::Dumper->Dump([$subsys]);
}

sub gengetgenehits {
    my($self,@Data) = @_;
    my $args = $self->check([
	["genome",1,undef,"SEED ID of the genome to be analyzed"]
    ],[@Data],"create gene similarity table");
    
    # code here
    my $fig_genome = $self->figmodel()->get_genome($args->{genome});

    my $result = $fig_genome->getGeneSimilarityHitTable();

    return $result;
}

sub gengettreehits {

}

1;
