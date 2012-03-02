

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
	ModelSEED::globals::CREATEFIGMODEL({username => ModelSEED::Interface::interface::USERNAME(),password => ModelSEED::Interface::interface::PASSWORD()});
	ModelSEED::Interface::interface::CREATEWORKSPACE({});
    return bless $self;
}
=head3 api
Definition:
	CoreAPI = driver->api();
Description:
	Returns a CoreAPI object
=cut
sub api {
	my ($self,$api) = @_;
	if (defined($biochemistry)) {
		$self->{_biochemistry} = $biochemistry;
	}
	if (!defined()) {
		my $data = $self->api()->getBiochemistry({
	    	uuid => ModelSEED::Interface::interface::BIOCHEMISTRY(),
			with_all => 1,
			user => ModelSEED::Interface::interface::USERNAME()
	    });
	    $self->{_biochemistry} = ModelSEED::MS::Biochemistry->new($data);
	}
	return $self->{_biochemistry};
}
=head3 biochemistry
Definition:
	Biochemistry = driver->biochemistry();
Description:
	Returns a Biochemistry object
=cut
sub biochemistry {
	my ($self,$biochemistry) = @_;
	if (defined($biochemistry)) {
		$self->{_biochemistry} = $biochemistry;
	}
	if (!defined()) {
		my $data = $self->api()->getBiochemistry({
	    	uuid => ModelSEED::Interface::interface::BIOCHEMISTRY(),
			with_all => 1,
			user => ModelSEED::Interface::interface::USERNAME()
	    });
	    $self->{_biochemistry} = ModelSEED::MS::Biochemistry->new($data);
	}
	return $self->{_biochemistry};
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

1;
