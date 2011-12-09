#!/usr/bin/perl -w

########################################################################
# Driver module that holds all functions that govern user interaction with the Model SEED
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 9/6/2011
########################################################################

use strict;
use ModelSEED::Interface::interface;
package ModelSEED::ModelDriver;

=head3 new
Definition:
	driver = driver->new();
Description:
	Returns a driver object
=cut
sub new { 
	my $self;
	ModelSEED::Interface::interface::CREATEWORKSPACE({});
    return bless $self;
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
	if (!defined($data) || @{$data} == 0) {
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
	my $output = $function." function usage:\n./".$function." ";
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
	return $output;
}
=head3 finish
Definition:
	void driver->finish(string:message);
Description:
	Closes out the ModelDriver with the specified message
=cut
sub finish {
	my ($self,$message) = @_;
	if (defined($self->{_finishedfile} ne "NONE")) {
	    if ($self->{_finishedfile} =~ m/^\//) {
	        ModelSEED::utilities::PRINTFILE($self->finishFile(),[$message]);
	    } else {
	    	ModelSEED::utilities::PRINTFILE(ModelSEED::Interface::interface::LOGDIRECTORY().$self->finishFile(),[$message]);
	    }
	}
	exit();
}

=head3 finishFile
Definition:
	FIGMODEL = driver->finishFile(string:message);
Description:
	Closes out the ModelDriver with the specified message
=cut
sub finishFile {
	my ($self,$file) = @_;
	if (defined($file)) {
		$self->{_finishedfile} = $file;
	}
	return $self->{_finishedfile};
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
	my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->mscreateuser($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
	return join("\n",@{$output->{MESSAGE}})."\n";
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
		["login",0,undef,"Login of the useraccount to be deleted."],
		["password",0,undef,"Password of the useraccount to be deleted."],
	],[@Data],"deleting the local instantiation of the specified user account");
	my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->msdeleteuser($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
	return join("\n",@{$output->{MESSAGE}})."\n";
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
	my $id = ModelSEED::interface::GETWORKSPACE()->id();
	ModelSEED::interface::GETWORKSPACE()->switchWorkspace({
		id => $args->{name},
		copy => $args->{copy},
		clear => $args->{clear}
	});
	my $output = {MESSAGE => [
		"Switched from workspace ".$id." to workspace ".ModelSEED::interface::GETWORKSPACE()->id()."!"
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
	my $output = {MESSAGE => ModelSEED::interface::GETWORKSPACE()->printWorkspace({
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
		["user",0,ModelSEED::interface::USERNAME(),"username to list workspaces for"]
	],[@Data],"print list of workspaces for user");
	my $list = ModelSEED::interface::GETWORKSPACE()->listWorkspaces({
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
	my $oldws = ModelSEED::interface::USERNAME().":".ModelSEED::interface::GETWORKSPACE()->id();
	my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->mslogin($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
	ModelSEED::interface::USERNAME($args->{username});
	ModelSEED::interface::PASSWORD($args->{password});
	ModelSEED::interface::CREATEWORKSPACE();
	ModelSEED::interface::UPDATEENVIRONMENT();
	$output->{MESSAGE} = [
		"You will remain logged in as \"".$args->{username}."\" until you run the \"login\" or \"logout\" functions.",
		"You have switched from workspace \"".$oldws."\" to workspace \"".$args->{username}.":".ModelSEED::interface::GETWORKSPACE()->id()."\"!"
	];
	return join("\n",@{$output->{MESSAGE}})."\n";
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
	my $oldws = ModelSEED::interface::USERNAME().":".ModelSEED::interface::GETWORKSPACE()->id();
	ModelSEED::interface::USERNAME("public");
	ModelSEED::interface::PASSWORD("public");
	ModelSEED::interface::CREATEWORKSPACE();
	ModelSEED::interface::UPDATEENVIRONMENT();
	my $output = {MESSAGE => [
		"Logout Successful!",
		"You will not be able to access user-associated data anywhere unless you log in again.",
		"You have switched from workspace \"".$oldws."\" to workspace \"public:".ModelSEED::interface::GETWORKSPACE()->id()."\"!"
	]};
	return join("\n",@{$output->{MESSAGE}})."\n";
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
	$args->{genomes} = ModelSEED::interface::PROCESSIDLIST({
		delimiter => ",",
		input => $args->{"genomes"}
	});
	$args->{sequences} = ModelSEED::interface::PROCESSIDLIST({
		delimiter => ",",
		input => $args->{"sequences"}
	});
	my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->sqblastgenomes($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
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
    foreach my $sequence (keys(%{$output->{RESULTS}})) {
    	foreach my $genome (keys(%{$output->{RESULTS}->{$sequence}})) {
    		my $line = $sequence."\t".$genome;
    		for (my $i=0; $i < @{$headings}; $i++) {
    			$line .= "\t".$output->{RESULTS}->{$sequence}->{$genome}->{$headings->[$i]};
    		}
    		push(@{$output},$line);
    	}
    }
	ModelSEED::utilities::PRINTFILE(ModelSEED::interface::GETWORKSPACE()->directory().$args->{"filename"},$output);
	return join("\n",@{$output->{MESSAGE}})."\n";
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
	],[@Data],"tests if a model is growing under a specific media");
	my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->fbacheckgrowth($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
	if (defined($output->{RESULTS}->{reactionFluxFile})) {
		push(@{$output->{MESSAGE}},"Reaction fluxes printed in ".ModelSEED::interface::GETWORKSPACE()->directory()."ReactionFluxes-".$args->{model}."-".$args->{media}.".txt");
		ModelSEED::utilities::PRINTFILE(ModelSEED::interface::GETWORKSPACE()->directory()."ReactionFluxes-".$args->{model}."-".$args->{media}.".txt",$output->{RESULTS}->{reactionFluxFile});	
	}
	if (defined($output->{RESULTS}->{compoundFluxFile})) {
		push(@{$output->{MESSAGE}},"Compound fluxes printed in ".ModelSEED::interface::GETWORKSPACE()->directory()."CompoundFluxes-".$args->{model}."-".$args->{media}.".txt");
		ModelSEED::utilities::PRINTFILE(ModelSEED::interface::GETWORKSPACE()->directory()."CompoundFluxes-".$args->{model}."-".$args->{media}.".txt",$output->{RESULTS}->{compoundFluxFile});	
	}
	if (defined($output->{RESULTS}->{lpfile})) {
		push(@{$output->{MESSAGE}},"FBA LP file printed in ".ModelSEED::interface::GETWORKSPACE()->directory()."FBAProblem-".$args->{model}."-".$args->{media}.".lp");
		ModelSEED::utilities::PRINTFILE(ModelSEED::interface::GETWORKSPACE()->directory()."FBAProblem-".$args->{model}."-".$args->{media}.".lp",$output->{RESULTS}->{lpfile});	
	}
	return join("\n",@{$output->{MESSAGE}})."\n";
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
		["maxDeletions",0,1,"A number specifying the maximum number of simultaneous knockouts to be simulated. We donot recommend specifying more than 2."],
		["rxnKO",0,undef,"A ',' delimited list of reactions to be knocked out during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where reactions to be knocked out are listed. This file MUST have a '.lst' extension."],
		["geneKO",0,undef,"A ',' delimited list of genes to be knocked out during the analysis. May also provide the name of a [[Gene Knockout File]] in the workspace where genes to be knocked out are listed. This file MUST have a '.lst' extension."],
		["drainRxn",0,undef,"A ',' delimited list of reactions whose reactants will be added as drain fluxes in the model during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where drain reactions are listed. This file MUST have a '.lst' extension."],
		["uptakeLim",0,undef,"Specifies limits on uptake of various atoms. For example 'C:1;S:5'"],
		["options",0,"forcedGrowth","A ';' delimited list of optional keywords that toggle the use of various additional constrains during the analysis. See [[Flux Balance Analysis Options Documentation]]."],
		["savetodb",0,0,"A FLAG that indicates that results should be saved to the database if set to '1'."],
	],[@Data],"simulate knockout of all combinations of one or more genes");
    my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->fbasingleko($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
	if (defined($output->{RESULTS}->{essentialGenes})) {
		my $filename = ModelSEED::interface::GETWORKSPACE()->directory().$args->{model}."-EssentialGenes.lst";
		ModelSEED::utilities::PRINTFILE($filename,$output->{RESULTS}->{essentialGenes});
		push(@{$output->{MESSAGE}},("Essential genes identified.","Essential genes listed in ".$filename));
	}
	return join("\n",@{$output->{MESSAGE}})."\n";
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
	my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->fbaminimalmedia($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
	if (defined($output->{minimalMediaResultsFile})) {
		push(@{$output->{MESSAGE}},("Essential nutrients successfully identified!","Data on essential and optional nutrients printed to ".ModelSEED::interface::GETWORKSPACE()->directory().$args->{model}."-MinimalMediaAnalysis.txt"));
		ModelSEED::utilities::PRINTFILE(ModelSEED::interface::GETWORKSPACE()->directory().$args->{model}."-MinimalMediaAnalysis.txt",$result->{minimalMediaResultsFile});
	}
	if (defined($output->{minimalMediaFile})) {
		push(@{$output->{MESSAGE}},("Essential media formulation successfully designed!","Media formulation printed to ".ModelSEED::interface::GETWORKSPACE()->directory().$args->{model}."-minimal.media"));
		ModelSEED::utilities::PRINTFILE(ModelSEED::interface::GETWORKSPACE()->directory().$args->{model}."-minimal.media",$result->{minimalMediaFile});
	}
	return join("\n",@{$output->{MESSAGE}})."\n";
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
		["variables",0,"FLUX;UPTAKE","A ';' delimited list of the variables that should be explored during the flux variability analysis. See [[List and Description of Variables Types used in Model SEED Flux Balance Analysis]]."],
		["rxnKO",0,undef,"A ',' delimited list of reactions to be knocked out during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where reactions to be knocked out are listed. This file MUST have a '.lst' extension."],
		["geneKO",0,undef,"A ',' delimited list of genes to be knocked out during the analysis. May also provide the name of a [[Gene Knockout File]] in the workspace where genes to be knocked out are listed. This file MUST have a '.lst' extension."],
		["drainRxn",0,undef,"A ',' delimited list of reactions whose reactants will be added as drain fluxes in the model during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where drain reactions are listed. This file MUST have a '.lst' extension."],
		["uptakeLim",0,undef,"Specifies limits on uptake of various atoms. For example 'C:1;S:5'"],
		["options",0,"forcedGrowth","A ';' delimited list of optional keywords that toggle the use of various additional constrains during the analysis. See [[Flux Balance Analysis Options Documentation]]. There are three options specifically relevant to the FBAFVA function: (i) the 'forcegrowth' option indicates that biomass must be greater than 10% of the optimal value in all flux distributions explored, (ii) 'nogrowth' means biomass is constrained to zero, and (iii) 'freegrowth' means biomass is left unconstrained."],		
		["savetodb",0,0,"If set to '1', this flag indicates that the results of the fva should be preserved in the Model SEED database associated with the indicated metabolic model. Database storage of results is necessary for results to appear in the Model SEED web interface."],
		["saveformat",0,"EXCEL","The format in which the output of the FVA should be stored. Options include 'EXCEL' or 'TEXT'."],
	],[@Data],"performs FVA (Flux Variability Analysis) studies");   	
   	my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->fbafva($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
	if (defined($output->{compoundTable}) && defined($output->{reactionTable})) {
		push(@{$output->{MESSAGE}},"Flux variability analysis of ".$args->{model}." in ".$args->{media}." successful!");
		if ($args->{saveformat} eq "EXCEL") {
			push(@{$output->{MESSAGE}},"Results printed in ".ModelSEED::interface::GETWORKSPACE()->directory().$args->{filename}.".xls");
			ModelSEED::utilities::MAKEXLS({
				filename => $self->ws()->directory().$args->{filename}.".xls",
				sheetnames => ["Compound Bounds","Reaction Bounds"],
				sheetdata => [$output->{compoundTable},$output->{reactionTable}]
			});
		} else ($args->{saveformat} eq "TEXT") {
			$output->{compoundTable}->save(ModelSEED::interface::GETWORKSPACE()->directory()."CompoundFVA-".$args->{model}."-".$args->{media}.".txt");
			$output->{reactionTable}->save(ModelSEED::interface::GETWORKSPACE()->directory()."ReactionFVA-".$args->{model}."-".$args->{media}.".txt");
			push(@{$output->{MESSAGE}},"Reaction FVA results printed in ".ModelSEED::interface::GETWORKSPACE()->directory()."ReactionFVA-".$args->{model}."-".$args->{media}.".txt");
			push(@{$output->{MESSAGE}},"Compound FVA results printed in ".ModelSEED::interface::GETWORKSPACE()->directory()."CompoundFVA-".$args->{model}."-".$args->{media}.".txt");
		}
	}
	return join("\n",@{$output->{MESSAGE}})."\n";
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
		["variables",0,"FLUX;UPTAKE","A ';' delimited list of the variables that should be explored during the flux variability analysis. See [[List and Description of Variables Types used in Model SEED Flux Balance Analysis]]."],	
		["rxnKO",0,undef,"A ',' delimited list of reactions to be knocked out during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where reactions to be knocked out are listed. This file MUST have a '.lst' extension."],
		["geneKO",0,undef,"A ',' delimited list of genes to be knocked out during the analysis. May also provide the name of a [[Gene Knockout File]] in the workspace where genes to be knocked out are listed. This file MUST have a '.lst' extension."],
		["drainRxn",0,undef,"A ',' delimited list of reactions whose reactants will be added as drain fluxes in the model during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where drain reactions are listed. This file MUST have a '.lst' extension."],
		["uptakeLim",0,undef,"Specifies limits on uptake of various atoms. For example 'C:1;S:5'"],
		["options",0,"forcedGrowth","A ';' delimited list of optional keywords that toggle the use of various additional constrains during the analysis. See [[Flux Balance Analysis Options Documentation]]. There are three options specifically relevant to the FBAFVA function: (i) the 'forcegrowth' option indicates that biomass must be greater than 10% of the optimal value in all flux distributions explored, (ii) 'nogrowth' means biomass is constrained to zero, and (iii) 'freegrowth' means biomass is left unconstrained."],
		["savetodb",0,0,"If set to '1', this flag indicates that the results of the fva should be preserved in the Model SEED database associated with the indicated metabolic model. Database storage of results is necessary for results to appear in the Model SEED web interface."],
		["saveformat",0,"EXCEL","The format in which the output of the FVA should be stored. Options include 'EXCEL' or 'TEXT'."],
	],[@Data],"performs FVA (Flux Variability Analysis) study of entire database");
    my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->fbafvabiomass($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
	if (defined($output->{compoundTable}) && defined($output->{reactionTable})) {
		push(@{$output->{MESSAGE}},"Flux variability analysis of ".$args->{biomass}." in ".$args->{media}." successful!");
		if ($args->{saveformat} eq "EXCEL") {
			push(@{$output->{MESSAGE}},"Results printed in ".ModelSEED::interface::GETWORKSPACE()->directory().$args->{filename}.".xls");
			ModelSEED::utilities::MAKEXLS({
				filename => $self->ws()->directory().$args->{filename}.".xls",
				sheetnames => ["Compound Bounds","Reaction Bounds"],
				sheetdata => [$output->{compoundTable},$output->{reactionTable}]
			});
		} else ($args->{saveformat} eq "TEXT") {
			$output->{compoundTable}->save(ModelSEED::interface::GETWORKSPACE()->directory()."CompoundFVA-".$args->{biomass}."-".$args->{media}.".txt");
			$output->{reactionTable}->save(ModelSEED::interface::GETWORKSPACE()->directory()."ReactionFVA-".$args->{biomass}."-".$args->{media}.".txt");
			push(@{$output->{MESSAGE}},"Reaction FVA results printed in ".ModelSEED::interface::GETWORKSPACE()->directory()."ReactionFVA-".$args->{model}."-".$args->{media}.".txt");
			push(@{$output->{MESSAGE}},"Compound FVA results printed in ".ModelSEED::interface::GETWORKSPACE()->directory()."CompoundFVA-".$args->{model}."-".$args->{media}.".txt");
		}
	}
	return join("\n",@{$output->{MESSAGE}})."\n";
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
		["filename",0,"MediaTable.txt","Filename where media table will be printed."]
	],[@Data],"print Model SEED media formulation");
    $args->{media} = ModelSEED::interface::processIDList({
		delimiter => ",",
		input => $args->{media}
	});
    my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->bcprintmediatable($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
	if (defined($output->{mediaCompoundTable})) {
		my $output = ["Compounds\t".join("\t",@{$args->{media}})];
		foreach my $compound (keys(%{$output->{mediaCompoundTable}})) {
			my $line = $compound;
			for (my $i=0; $i < @{$args->{media}}; $i++) {
				$line .= "\t".$output->{mediaCompoundTable}->{$compound}->{$mediaIDs->[$i]};
			}
			push(@{$output},$line);
		}
		ModelSEED::utilities::PRINTFILE(ModelSEED::interface::GETWORKSPACE()->directory().$args->{filename},$output);
	    push(@{$output->{MESSAGE}},"Media table printed to ".ModelSEED::interface::GETWORKSPACE()->directory().$args->{filename});
	
	}
	return join("\n",@{$output->{MESSAGE}})."\n";
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
    my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->bcprintmedia($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
    if (defined($output->{mediaFile})) {
		ModelSEED::utilities::PRINTFILE(ModelSEED::interface::GETWORKSPACE()->directory().$args->{media}.".media",$output->{mediaFile});
	    push(@{$output->{MESSAGE}},"Successfully printed media to ".ModelSEED::interface::GETWORKSPACE()->directory().$args->{media}.".media",$output->{mediaFile});
	
	}
	return join("\n",@{$output->{MESSAGE}})."\n";
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
		["owner",0,ModelSEED::interface::USERNAME(),"Login of the user account who will own this media condition."],
		["overwrite",0,0,"If you set this parameter to '1', any existing media with the same input name will be overwritten."]
	],[@Data],"Creates (or alters) a media condition in the Model SEED database");
    my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
    if (!-e ModelSEED::interface::GETWORKSPACE()->directory().$args->{media}) {
    	ModelSEED::utilities::ERROR("Could not find specified media file ".ModelSEED::interface::GETWORKSPACE()->directory().$args->{media});
    }
    $args->{mediaFile} = ModelSEED::utilities::LOADFILE(ModelSEED::interface::GETWORKSPACE()->directory().$args->{media});
	my $output = $cmdapi->bcloadmedia($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
    if (defined($output->{mediaID})) {
	    push(@{$output->{MESSAGE}},"Successfully loaded media ".$output->{mediaID}." to database!");
	}
	return join("\n",@{$output->{MESSAGE}})."\n";
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
    my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->mdlautocomplete($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
	if (defined($output->{gapfillReportFile})) {
		ModelSEED::utilities::PRINTFILE(ModelSEED::interface::GETWORKSPACE()->directory()."AutocompletionReport-".$args->{model}."-".$args->{media}.".txt",$output->{gapfillReportFile});
		push(@{$output->{MESSAGE}},"Successfully autocompleted model ".$args->{model}." in ".$args->{media}." media!");
		push(@{$output->{MESSAGE}},"Printed autocompletion results to ".ModelSEED::interface::GETWORKSPACE()->directory()."AutocompletionReport-".$args->{model}."-".$args->{media}.".txt");
	}
	return join("\n",@{$output->{MESSAGE}})."\n";
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
    my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->mdlreconstruction($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
	push(@{$output->{MESSAGE}},"Generated model from genome annotations");
    return join("\n",@{$output->{MESSAGE}})."\n";
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
    my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->mdlmakedbmodel($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
	push(@{$output->{MESSAGE}},"Set model reaction list to entire biochemistry database");
    return join("\n",@{$output->{MESSAGE}})."\n";
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
	my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->mdladdright($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
	push(@{$output->{MESSAGE}},"Successfully added ".$args->{right}." rights for user ".$args->{user}." to model ".$args->{model}."!");
    return join("\n",@{$output->{MESSAGE}})."\n";
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
		["genome",1,undef,"Genome for which new model should be created."],
		["id",0,undef,"ID that the new model should have in the Model SEED database."],
		["biomass",0,undef,"ID of the biomass reaction the new model should have in the Model SEED database."],
		["owner",0,ModelSEED::interface::USERNAME(),"The login of the user account that should own the new model."],
		["biochemSource",0,undef,"Path to an existing biochemistry provenance database that should be used for provenance in the new model."],
		["reconstruction",0,1,"Set this FLAG to '1' to autoatically run the reconstruction algorithm on the new model as soon as it is created."],
		["autocompletion",0,0,"Set this FLAG to '1' to autoatically run the autocompletion algorithm on the new model as soon as it is created."],
		["overwrite",0,0,"Set this FLAG to '1' to overwrite any model that has the same specified ID in the database."],
	],[@Data],"create new Model SEED models");
    my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->mdlcreatemodel($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
	push(@{$output->{MESSAGE}},"Successfully created model ".$args->{model}."!");
    return join("\n",@{$output->{MESSAGE}})."\n";
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
	my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->mdlinspectstate($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
	push(@{$output->{MESSAGE}},"Successfully inspected the state of model ".$args->{model}."!");
    return join("\n",@{$output->{MESSAGE}})."\n";
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
	my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->mdlprintsbml($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
	if (defined($output->{sbmlfile})) {
		push(@{$output->{MESSAGE}},"Succesfully printed SBML file for ".$args->{model}." in media ".$args->{media}."!");
		push(@{$output->{MESSAGE}},"SBML file printed to ".ModelSEED::interface::GETWORKSPACE()->directory()."SBML-".$args->{model}."-".$args->{media}.".xml");
		ModelSEED::utilities::PRINTFILE(ModelSEED::interface::GETWORKSPACE()->directory()."SBML-".$args->{model}."-".$args->{media}.".xml",$output->{sbmlfile});
	}
    return join("\n",@{$output->{MESSAGE}})."\n";
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
		["model",1,undef,"The full Model SEED ID of the model to be printed."]
	],[@Data],"prints a model to flatfile for alteration and reloading");
	my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->mdlprintmodel($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
	if (defined($output->{modelfile})) {
		push(@{$output->{MESSAGE}},"Succesfully printed reaction table for ".$args->{model}."!");
		push(@{$output->{MESSAGE}},"Reaction table printed to ".ModelSEED::interface::GETWORKSPACE()->directory().$args->{model}.".mdl");
		ModelSEED::utilities::PRINTFILE(ModelSEED::interface::GETWORKSPACE()->directory().$args->{model}.".mdl",$output->{modelfile});
	}
	if (defined($output->{biomassfile})) {
		push(@{$output->{MESSAGE}},"Succesfully printed biomass reaction ".$output->{biomassID}." for ".$args->{model}."!");
		push(@{$output->{MESSAGE}},"Biomass data printed to ".ModelSEED::interface::GETWORKSPACE()->directory().$output->{biomassID}.".bof");
		ModelSEED::utilities::PRINTFILE(ModelSEED::interface::GETWORKSPACE()->directory().$output->{biomassID}.".bof",$output->{biomassfile});
	}
    return join("\n",@{$output->{MESSAGE}})."\n";
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
	my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->mdlprintcytoseed($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
	if (defined($output->{modeldata})) {
		open(FH, ">".$cmdir."/model_data") or ModelSEED::utilities::ERROR("Could not open file: $!\n");
		print FH $dumper->dump($output->{modeldata});
		close FH;
	}
	if (defined($output->{biomassdata})) {
		open(FH, ">".$cmdir."/biomass_reaction_details") or ModelSEED::utilities::ERROR("Could not open file: $!\n");
		print FH $dumper->dump($output->{biomassdata});
		close FH;
	}
	if (defined($output->{compounddata})) {
		open(FH, ">".$cmdir."/compound_details") or ModelSEED::utilities::ERROR("Could not open file: $!\n");
		print FH $dumper->dump($output->{compounddata});
		close FH;
	}
	if (defined($output->{abstractcompounddata})) {
		open(FH, ">".$cmdir."/abstract_compound_details") or ModelSEED::utilities::ERROR("Could not open file: $!\n");
		print FH $dumper->dump($output->{abstractcompounddata});
		close FH;
	}
	if (defined($output->{reactiondata})) {
		open(FH, ">".$cmdir."/reaction_details") or ModelSEED::utilities::ERROR("Could not open file: $!\n");
		print FH $dumper->dump($output->{reactiondata});
		close FH;
	}
	if (defined($output->{abstractreactiondata})) {
		open(FH, ">".$cmdir."/abstract_reaction_details") or ModelSEED::utilities::ERROR("Could not open file: $!\n");
		print FH $dumper->dump($output->{abstractreactiondata});
		close FH;
	}
	if (defined($output->{reactionclassifications})) {
		open(FH, ">".$cmdir."/reaction_classifications") or ModelSEED::utilities::ERROR("Could not open file: $!\n");
		print FH $dumper->dump($output->{reactionclassifications});
		close FH;
	}
	return "Successfully printed cytoseed data for ".$args->{model}." in directory:\n".$args->{directory}."\n";
    return join("\n",@{$output->{MESSAGE}})."\n";
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
	],[@Data],"print all genes in model");
	my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->mdlprintmodelgenes($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
	if (defined($output->{geneList})) {
		push(@{$output->{MESSAGE}},"Succesfully printed gene list for ".$args->{model}."!");
		push(@{$output->{MESSAGE}},"Gene list printed to ".ModelSEED::interface::GETWORKSPACE()->directory()."GeneList-".$args->{model}."lst");
		ModelSEED::utilities::PRINTFILE(ModelSEED::interface::GETWORKSPACE()->directory()."GeneList-".$args->{model}."lst",[keys(%{$ftrHash})];
	}
    return join("\n",@{$output->{MESSAGE}})."\n";
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
		["model",1,undef,"ID of the model to be loaded (Please DO append your user ID!)."],
    	["genome",1,undef,"The SEED genome ID associated with the model to be loaded."],
    	["filename",0,undef,"The full path and name of the file where the reaction table for the model to be imported is located. [[Example model file]]."],
    	["biomassFile",0,undef,"The full path and name of the file where the biomass reaction for the model to be imported is located. [[Example biomass file]]."],
    	["owner",0,ModelSEED::interface::USERNAME(),"The login name of the user that should own the loaded model"],
    	["provenance",0,undef,"The name of an existing model for which the provenance database should be copied. If not provided, the Model SEED will generate a new provenance database from scratch using current system data."],
    	["overwrite",0,0,"If you are attempting to load a model that already exists in the database, you MUST set this argument to '1'."],
    	["public",0,0,"If you want the loaded model to be publicly viewable to all Model SEED users, you MUST set this argument to '1'."],
    	["autoCompleteMedia",0,"Complete","Name of the media used for auto-completing this model."]
	],[@Data],"reload a model from a flatfile");
	if (!defined($args->{filename})) {
		$args->{filename} = ModelSEED::interface::GETWORKSPACE()->directory().$args->{model}.".mdl";
	}
	if (!-e $args->{filename}) {
		ModelSEED::utilities::USEERROR("Model file ".$args->{filename}." not found. Check file and input.");
	}
	$args->{modelfiledata} = ModelSEED::interface::LOADFILE($args->{filename});
	if (!defined($args->{biomassFile})) {
		my $biomassID;
		for (my $i=0; $i < @{$args->{modelfiledata}};$i++) {
			if ($args->{modelfiledata}->[$i] =~ m/^(bio\d+);/) {
				$biomassID = $1;
			}
		}
		$args->{biomassFile} = ModelSEED::interface::GETWORKSPACE()->directory().$biomassID.".bof";
	}
	if (-e $args->{biomassFile}) {
		my $obj = ModelSEED::FIGMODEL::FIGMODELObject->new({filename=>$args->{biomassFile},delimiter=>"\t",-load => 1});
		$args->{biomassEquation} = $obj->{EQUATION}->[0];
		$args->{biomassid} = $obj->{DATABASE}->[0];
	}
	my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->mdlloadmodel($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
    return join("\n",@{$output->{MESSAGE}})."\n";
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
	my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->mdlchangedrains($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
    return join("\n",@{$output->{MESSAGE}})."\n";
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
	if (!-e ModelSEED::interface::GETWORKSPACE()->directory().$args->{biomass}) {
    	ModelSEED::utilities::ERROR("Could not find specified SBML file ".ModelSEED::interface::GETWORKSPACE()->directory().$args->{file});
    }
    $args->{biomassid} = $args->{biomass};
	if (!defined($args->{equation})) {
		#Setting the filename if only an ID was specified
		my $filename = $args->{biomass};
		if ($filename =~ m/^bio\d+$/) {
			$filename = ModelSEED::interface::GETWORKSPACE()->directory().$args->{biomass}.".bof";
		}
		#Loading the biomass reaction
		ModelSEED::utilities::ERROR("Could not find specified biomass file ".$filename."!") if (!-e $filename);
		#Loading biomass reaction file
		my $obj = ModelSEED::FIGMODEL::FIGMODELObject->new({filename=>$filename,delimiter=>"\t",-load => 1});
		$args->{equation} = $obj->{EQUATION}->[0];
		if ($args->{biomass} =~ m/(^bio\d+)/) {
			$obj->{DATABASE}->[0] = $1;
		}
		$args->{biomassid} = $obj->{DATABASE}->[0];
	}
	my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->mdlloadbiomass($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
    return join("\n",@{$output->{MESSAGE}})."\n";
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
		["file",1,undef,"The name of the SBML file to be parsed. It is assumed the file is present in the workspace."],
		["name",0,undef,"The name of the model being parsed, which will be used to name the output files"],
	],[@Data],"parsing SBML file into compound and reaction tables");
	if (!-e ModelSEED::interface::GETWORKSPACE()->directory().$args->{file}) {
    	ModelSEED::utilities::ERROR("Could not find specified SBML file ".ModelSEED::interface::GETWORKSPACE()->directory().$args->{file});
    }
	$args->{filedata} = ModelSEED::interface::LOADFILE(ModelSEED::interface::GETWORKSPACE()->directory().$args->{file});
	if (!defined($args->{name})) {
		$name = substr($args->{file},rindex($args->{file},'/')+1,rindex($args->{file},'.')-rindex($args->{file},'/')-1);
	}
	my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->mdlparsesbml($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
	foreach my $table (keys(%{$output})) {
		my $filename = ModelSEED::interface::GETWORKSPACE()->directory().$args->{name}."-".$table.".tbl";
		$output->{$table}->save($filename);
		push(@{$output->{MESSAGE}},$table." table printed to ".$filename);
	}
    return join("\n",@{$output->{MESSAGE}})."\n";
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
    	["owner",0,ModelSEED::interface::USERNAME(),"Name of the user account that will own the imported model."],
    	["path",0,ModelSEED::interface::GETWORKSPACE()->directory(),"The path where the compound and reaction files containing the model data to be imported are located."],
    	["overwrite",0,0,"Set this FLAG to '1' to overwrite an existing model with the same name."],
    	["biochemsource",0,undef,"The path to the directory where the biochemistry database that the model should be imported into is located."]
    ],[@Data],"import a model into the Model SEED environment");
	if (!-e $args->{path}.$args->{name}."-reactions.tbl") {
		ModelSEED::utilities::ERROR("could not find import file:".$args->{path}.$args->{name}."-reactions.tbl");
	}
	if (!-e $args->{path}.$args->{name}."-compounds.tbl") {
		ModelSEED::utilities::ERROR("could not find import file:".$args->{path}.$args->{name}."-compounds.tbl");
	}
	$args->{reactionTable} = ModelSEED::FIGMODEL::FIGMODELTable::load_table($args->{path}.$args->{name}."-reactions.tbl","\t","|",0,["ID"]);
	$args->{compoundTable} = ModelSEED::FIGMODEL::FIGMODELTable::load_table($args->{path}.$args->{name}."-compounds.tbl","\t","|",0,["ID"]);
	my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->mdlimportmodel($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
	if (defined($output->{outputFile})) {
		ModelSEED::utilities::PRINTFILE(ModelSEED::interface::GETWORKSPACE()->directory()."ImportReport-".$args->{name}.".txt",$output->{outputFile});
		push(@{$output->{MESSAGE}},"Model import report printed in ".ModelSEED::interface::GETWORKSPACE()->directory()."ImportReport-".$args->{name}.".txt");
	}	
    return join("\n",@{$output->{MESSAGE}})."\n";
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
	if (!-e ModelSEED::interface::GETWORKSPACE()->directory().$args->{matrixfile}) {
		ModelSEED::utilities::ERROR("Could not find matrix file ".ModelSEED::interface::GETWORKSPACE()->directory().$args->{matrixfile}."!");
	}
	$args->{matrix} = ModelSEED::utilities::LOADFILE(ModelSEED::interface::GETWORKSPACE()->directory().$args->{matrixfile});
    my $cmdapi = ModelSEED::interface::GETCOMMANDAPI();
	my $output = $cmdapi->utilmatrixdist($args);
	if (defined($output->{ERROR})) {
		ModelSEED::utilities::ERROR($output->{ERROR});
	}
	if (defined($output->{distfiledata})) {
		foreach my $filename (keys(%{$output->{distfiledata}})) {
			ModelSEED::utilities::PRINTFILE(ModelSEED::interface::GETWORKSPACE()->directory().$filename,$output->{distfiledata}->{$filename});
			push(@{$output->{MESSAGE}},"Printed distribution data to ".ModelSEED::interface::GETWORKSPACE()->directory().$filename);
		}
	}
    return join("\n",@{$output->{MESSAGE}})."\n";
}

1;
