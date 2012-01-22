use strict;
use warnings;
#use ModelSEED::TestingHelpers;
use Test::More tests => 29;
use File::Path;
use Data::Dumper;
use ModelSEED::Interface::interface;

#Testing each server function
{
	#Checking directories
	ok ModelSEED::Interface::interface::BOOTSTRAPFILE() eq ModelSEED::Interface::interface::MODELSEEDDIRECTORY()."/config/ModelSEEDbootstrap.pm", "BOOTSTRAPFILE function working!";
	ok ModelSEED::Interface::interface::LOGDIRECTORY() eq ModelSEED::Interface::interface::MODELSEEDDIRECTORY()."/log/", "LOGDIRECTORY function working!";
	ok ModelSEED::Interface::interface::BINDIRECTORY() eq ModelSEED::Interface::interface::MODELSEEDDIRECTORY()."/bin/", "BINDIRECTORY function working!";
	ok ModelSEED::Interface::interface::WORKSPACEDIRECTORY() eq ModelSEED::Interface::interface::MODELSEEDDIRECTORY()."/workspace/", "WORKSPACEDIRECTORY function working!";
	#Making test data directory
	if (!-d ModelSEED::Interface::interface::MODELSEEDDIRECTORY()."/data/testdata/") {
    	File::Path::mkpath(ModelSEED::Interface::interface::MODELSEEDDIRECTORY()."/data/testdata/");
	}
	#Creating test environment
    ModelSEED::Interface::interface::ENVIRONMENT({
    	USERNAME => "test",
    	PASSWORD => "test",
		WORKSPACEFOLDER => "test",
		SEED => "local",
		REGISTEREDSEEDS => {
			Argonne => "pubseed.theseed.org/models/"
		} 
    });
    #Checking the environment
    ok ModelSEED::Interface::interface::USERNAME() eq "test","USERNAME and ENVIRONMENT function working!";
    ok ModelSEED::Interface::interface::PASSWORD() eq "test","PASSWORD and ENVIRONMENT function working!";
    ok ModelSEED::Interface::interface::SEED() eq "local","SEED and ENVIRONMENT function working!";
    ok ModelSEED::Interface::interface::WORKSPACEFOLDER() eq "test","WORKSPACEFOLDER and ENVIRONMENT function working!";
    ok defined(ModelSEED::Interface::interface::REGISTEREDSEED()->{Argonne}) && ModelSEED::Interface::interface::REGISTEREDSEED()->{Argonne} eq "pubseed.theseed.org/models/","REGISTEREDSEED function working!";
    #Saving the environment
    ModelSEED::Interface::interface::ENVIRONMENTFILE(ModelSEED::Interface::interface::MODELSEEDDIRECTORY()."/data/testdata/testenvironment.env");
    ModelSEED::Interface::interface::SAVEENVIRONMENT();
    ok -e ModelSEED::Interface::interface::ENVIRONMENTFILE(), "ENVIRONMENTFILE, MODELSEEDDIRECTORY, and SAVEENVIRONMENT function working!";
    #Clearing the environment
    ModelSEED::Interface::interface::ENVIRONMENT({});
    #Loading the environment
    ModelSEED::Interface::interface::LOADENVIRONMENT();
    ok ModelSEED::Interface::interface::USERNAME() eq "test","USERNAME and LOADENVIRONMENT function working!";
    ok ModelSEED::Interface::interface::PASSWORD() eq "test","PASSWORD and LOADENVIRONMENT function working!";
    ok ModelSEED::Interface::interface::SEED() eq "local","SEED and LOADENVIRONMENT function working!";
    ok ModelSEED::Interface::interface::WORKSPACEFOLDER() eq "test","WORKSPACEFOLDER and LOADENVIRONMENT function working!";
    ok defined(ModelSEED::Interface::interface::REGISTEREDSEED()->{Argonne}) && ModelSEED::Interface::interface::REGISTEREDSEED()->{Argonne} eq "pubseed.theseed.org/models/","REGISTEREDSEED function working!";
    #Loading workspace
    my $workspace = ModelSEED::Interface::interface::WORKSPACE();
    ok defined($workspace) && $workspace->directory() eq ModelSEED::Interface::interface::WORKSPACEDIRECTORY()."/test/test/","WORKSPACE, CREATEWORKSPACE, and WORKSPACEDIRECTORY function working!";
    #Testing process ID list function
    my $output = ModelSEED::Interface::interface::PROCESSIDLIST({
    	input => "One;Two;Three",
    	delimiter => "[,;]",
		validation => undef
    });
    ok defined($output->[2]) && $output->[2] eq "Three","PROCESSIDLIST function working!";
    #Testing command API
    my $cmdapi = ModelSEED::Interface::interface::COMMANDAPI();
    ok defined($cmdapi),"COMMANDAPI function working!";
}
=cut
