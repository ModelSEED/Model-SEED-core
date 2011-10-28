use strict;
package ModelSEED::FIGMODEL::workspace;
use Scalar::Util qw(weaken);

=head1

=head2 Introduction
Module for maintaining workspace for user

=head2 Core Object Methods

=head3 new
Definition:
	workspace = workspace->new();
Description:
	This is the constructor for the workspace object.
=cut

sub new {
	my ($class,$args) = @_;
	if (!defined($args->{figmodel})) {
		ModelSEED::FIGMODEL::FIGMODELERROR("FIGMODEL must be defined to create workspace object!");
	}
	$args = $args->{figmodel}->process_arguments($args,[],{
		id => undef,
		owner => $args->{figmodel}->user(),
		clear => 0,
		copy => undef
	});
	if (!defined($args->{owner}) || $args->{owner} eq "") {
		ModelSEED::FIGMODEL::FIGMODELERROR("A username must be specified to determine the workspace!");
	}
	my $self = {_figmodel => $args->{figmodel}, _owner => $args->{owner}};
	Scalar::Util::weaken($self->{_figmodel});
	bless $self;
	if (!defined($args->{id})) {
		$self->loadCurrentWorkspace();
	} else {
		$self->{_id} = $args->{id};
	}	
	if ($self->id() !~ m/[\w\s]/) {
		ModelSEED::FIGMODEL::FIGMODELERROR("Workspace names can only contain letters, numbers, spaces and underscores!");
	}
	$self->makeDirectory({
		clear => $args->{clear},
		copy => $args->{copy}
	});
	return $self;
}
=head3 figmodel
Definition:
	FIGMODEL = workspace->figmodel();
Description:
	Returns a FIGMODEL object
=cut
sub figmodel {
	my ($self) = @_;
	return $self->{_figmodel};
}
=head3 db
Definition:
	FIGMODEL = workspace->db();
Description:
	Returns a FIGMODELdatabase object
=cut
sub db {
	my ($self) = @_;
	return $self->{_figmodel}->database();
}
=head3 config
Definition:
	ref::key value = workspace->config(string::key);
Description:
	Trying to avoid using calls that assume configuration data is stored in a particular manner.
	Call this function to get file paths etc.
=cut
sub config {
	my ($self,$key) = @_;
	return $self->figmodel()->config($key);
}
=head3 process_arguments
Definition:
	{key=>value} = workspace->process_arguments( {key=>value} );
Description:
	Processes arguments to authenticate users and perform other needed tasks
=cut
sub process_arguments {
	my ($self,$args,$mandatoryArguments,$optionalArguments,$noblank) = @_;
	if ($noblank == 1 && !defined($self->id())) {
		ModelSEED::FIGMODEL::FIGMODELERROR("Cannot call this function using a blank workspace!");
	}
	return $self->figmodel()->process_arguments($args,$mandatoryArguments,$optionalArguments);
}
=head3 id
Definition:
	string = workspace->id();
Description:
	Getter for workspace id
=cut
sub id {
	my ($self) = @_;
	return $self->{_id};
}
=head3 owner
Definition:
	string = workspace->owner();
Description:
	Getter for workspace owner
=cut
sub owner {
	my ($self) = @_;
	return $self->{_owner};
}
=head3 directory
Definition:
	path = workspace->directory();
Description:
	Returns the directory where the current workspace is located 
=cut
sub directory {
	my ($self) = @_;
	$self->process_arguments({},[],{},1);
	if (!defined($self->{_directory})) {
		my $id = $self->id();
		$id =~ s/\s/_/g;
		$self->{_directory} = $self->config("Workspace directory")->[0].$self->owner()."/".$id."/";
	}
	return $self->{_directory};
}
=head3 path
Definition:
	path = workspace->path();
Description:
	Returns the path where the all workspaces are located 
=cut
sub path {
	my ($self) = @_;
	$self->process_arguments({},[],{},1);
	$self->{_directory} = $self->config("Workspace directory")->[0];
	return $self->{_directory};
}

=head3 makeDirectory
Definition:
	path = workspace->makeDirectory();
Description:
	Creates workspace directory if needed 
=cut
sub makeDirectory {
	my ($self,$args) = @_;
	$self->process_arguments($args,[],{
		clear => 0,
		copy => undef
	},1);
	if ($args->{clear} == 1) {
		File::Path::rmtree($self->directory());
	}
	File::Path::mkpath($self->directory());
	if (defined($args->{copy})) {
		$args->{copy} =~ s/\s/_/g;
		if (!-d $self->config("Workspace directory")->[0].$self->owner()."/".$args->{copy}) {
			ModelSEED::FIGMODEL::FIGMODELERROR("Could not find copy workspace ".$args->{copy}."!");
		}
		File::Copy::Recursive::dircopy($self->config("Workspace directory")->[0].$self->owner()."/".$args->{copy}, $self->directory());
	}
}
=head3 clearDirectory()
Definition:
	path = workspace->clearDirectory();
Description:
	Clears the workspace directory
=cut
sub clearDirectory {
	my ($self,$args) = @_;
	$self->process_arguments($args,[],{},1);
	File::Path::rmtree($self->directory());
	File::Path::mkpath($self->directory());
}
=head3 loadCurrentWorkspace
Definition:
	void workspace->loadCurrentWorkspace();
Description:
	Sets the ID of the workspace from a file located in the owner's workspace directory
=cut
sub loadCurrentWorkspace {
	my ($self,$args) = @_;
	$self->process_arguments($args,[],{},0);
	if (!-d $self->config("Workspace directory")->[0].$self->owner()) {
		File::Path::mkpath($self->config("Workspace directory")->[0].$self->owner());
	}
	if (!-e $self->config("Workspace directory")->[0].$self->owner()."/current.txt") {
		$self->db()->print_array_to_file($self->config("Workspace directory")->[0].$self->owner()."/current.txt",["default"]);
	}
	my $data = $self->db()->load_single_column_file($self->config("Workspace directory")->[0].$self->owner()."/current.txt","");
	$self->{_id} = $data->[0];
}
=head3 setAsCurrentWorkspace
Definition:
	void workspace->setAsCurrentWorkspace();
Description:
	Sets the current workspace of the logged in user to this workspace
=cut
sub setAsCurrentWorkspace {
	my ($self,$args) = @_;
	$self->process_arguments($args,[],{},1);
	$self->db()->print_array_to_file($self->config("Workspace directory")->[0].$self->owner()."/current.txt",[$self->id()]);
}
=head3 printWorkspace
Definition:
	string = workspace->printWorkspace();
Description:
	Returns a descriptions of the workspace
=cut
sub printWorkspace {
	my ($self,$args) = @_;
	$self->process_arguments($args,[],{
		verbose => 0
	},1);
	my $msg = "Current workspace:".$self->owner().":".$self->id()."\n".
		"All output will be printed in ".$self->directory()."\n";
	return $msg;
}
=head3 workspaceList
Definition:
	[path] = workspace->workspaceList({
		owner => username
	});
Description:
	return a list of all workspaces owned by presently logged user
=cut
sub workspaceList {
	my ($self,$args) = @_;
	$self->process_arguments($args,[],{
		owner => $self->figmodel()->user()
	},0);
	my $owners = [$args->{owner}];
	if ($args->{owner} eq "ALL") {
		$owners = glob($self->config("Workspace directory")->[0]."*");
		for (my $i=0; $i < @{$owners}; $i++) {
			if ($owners->[$i] =~ m/\/([^\/]+)$/) {
				$owners->[$i] = $1;
			}
		}
	}
	my $list;
	for (my $i=0; $i < @{$owners};$i++) {
		my $tempList = glob($self->config("Workspace directory")->[0].$owners->[$i]."/*");
		for (my $j=0; $j < @{$tempList}; $j++) {
			if ($tempList->[$j] !~ m/current\.txt$/ && $tempList->[$j] =~ m/\/([^\/]+)$/) {
				push(@{$list},$owners->[$i].":".$1);
			}
		}
	}
	return $list;
}

1;
