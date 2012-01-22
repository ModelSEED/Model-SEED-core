use strict;
use warnings;
use File::Path;
use File::Copy::Recursive;
use ModelSEED::utilities;
package ModelSEED::Interface::workspace;

=head3 new
Definition:
	workspace = ModelSEED::Interface::workspace->new();
Description:
	Returns a workspace object
=cut
sub new { 
	my ($class,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[
		"owner",
		"root",
		"binDirectory"
	],{
		clear => 0,
		copy => undef
	});
	my $self = {
		_owner => $args->{owner},
		_root => $args->{root},
		_binDirectory => $args->{binDirectory}
	};
	bless $self;
	if($args->{clear} eq 1) {
        $self->clear();
    }
    if(defined($args->{copy})) {
    	$self->copy($args->{copy});
    }
	File::Path::mkpath($self->directory) unless(-f $self->directory);
	$self->printWorkspaceEnvFiles();
    return $self;
}
=head3 id
Definition:
	workspace = ModelSEED::Interface::workspace->id();
Description:
	Returns an ID string
=cut
sub id { 
	my ($self,$id) = @_;
	if (defined($id)) {
		$self->{_id} = $id;
	}
	if (!defined($self->{_id})) {
		my $currentFile = $self->root().$self->owner()."/current.txt";
		if(-f $currentFile) {
	    	my $data = ModelSEED::utilities::LOADFILE($self->root().$self->owner()."/current.txt");
	    	$self->{_id} = $data->[0]; 
	    } else {
	    	$self->{_id} = 'default';
	    }
	}
	return $self->{_id};
}
=head3 directory
Definition:
	workspace = ModelSEED::Interface::workspace->directory();
Description:
	Returns a directory string
=cut
sub directory { 
	my ($self) = @_;
	if (!defined($self->{_directory})) {
		$self->{_directory} = $self->root().$self->owner()."/".$self->id()."/";
	}
	return $self->{_directory};
}
=head3 owner
Definition:
	workspace = ModelSEED::Interface::workspace->owner();
Description:
	Returns a owner string
=cut
sub owner { 
	my ($self) = @_;
	return $self->{_owner};
}
=head3 root
Definition:
	workspace = ModelSEED::Interface::workspace->root();
Description:
	Returns a root string
=cut
sub root { 
	my ($self) = @_;
	return $self->{_root};
}
=head3 binDirectory
Definition:
	workspace = ModelSEED::Interface::workspace->binDirectory();
Description:
	Returns a binDirectory string
=cut
sub binDirectory { 
	my ($self) = @_;
	return $self->{_binDirectory};
}

=head3 clear
Definition:
	workspace = ModelSEED::Interface::workspace->clear();
Description:
	Clears existing workspace directory
=cut
sub clear {
    File::Path::rmtree($_[0]->directory);
    File::Path::mkpath($_[0]->directory);
}
=head3 copy
Definition:
	workspace = ModelSEED::Interface::workspace->copy({
		owner => string,
		id => string
	});
Description:
	Copies a specified workspace into the current workspace
=cut
sub copy {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["owner","id"],{});
	if (!-d $self->root().$self->owner()."/".$self->id()."/") {
		ModelSEED::utilities::ERROR("Cannot find workspace directory to be copied: ".$self->root().$self->owner()."/".$self->id()."/");
	}
	File::Copy::Recursive::dircopy($self->root().$self->owner()."/".$self->id()."/", $self->directory);
}

=head3 printWorkspaceEnvFiles
Definition:
	workspace = ModelSEED::Interface::workspace->printWorkspaceEnvFiles();
Description:
	Prints files defining workspace
=cut
sub printWorkspaceEnvFiles {
    my ($self) = @_;
    ModelSEED::utilities::PRINTFILE($self->root().$self->owner()."/current.txt",[$self->id()]);
    ModelSEED::utilities::PRINTFILE($self->binDirectory()."ms-goworkspace",["cd ".$self->directory()]);
	chmod 0775, $self->binDirectory()."ms-goworkspace";
}

=head3 printWorkspace
Definition:
	workspace = ModelSEED::Interface::workspace->printWorkspace();
Description:
	Prints the contents of the workspace
=cut
sub printWorkspace {
    my ($self) = @_;
    my ($owner, $id, $dir) = ($self->owner, $self->id, $self->directory);
    return "Current workspace: $owner.$id\nAll output will be printed in $dir\n"
}
=head3 switchWorkspace
Definition:
    ModelSEED::Interface::workspace->switchWorkspace({
		id => string:new workspace name
		copy => {
			owner => string,
			id => string
		}
		clear => 0/1:clears the workspace directory before using it
	});
Description:
	Switches and creates a new workspace
=cut
sub switchWorkspace {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["id"],{
		clear => 0,
		copy => undef
	});
	if($args->{clear} eq 1) {
        $self->clear();
    }
    if(defined($args->{copy})) {
    	$self->copy($args->{copy});
    }
	$self->id($args->{id});
	$self->printWorkspaceEnvFiles();
}
=head3 listWorkspaces
Definition:
    string = ModelSEED::Interface::workspace->listWorkspaces({
        owner => username
    });
Description:
    Return a list of all workspaces owned by username.
    Default username is currently logged in user.
    
=cut
sub listWorkspaces {
    my ($self,$args) = @_;
    $args = ModelSEED::utilities::ARGS($args,[],{
		owner => $self->user()
	});
    my $owners = [$args->{owner}];
    if ($args->{owner} eq "ALL") {
        $owners = [glob($self->root()."*")];
        for (my $i=0; $i < @{$owners}; $i++) {
            if ($owners->[$i] =~ m/\/([^\/]+)$/) {
                $owners->[$i] = $1;
            }
        }
    }
    my $list;
    for (my $i=0; $i < @{$owners};$i++) {
        my $tempList = [glob($self->root().$owners->[$i]."/*")];
        for (my $j=0; $j < @{$tempList}; $j++) {
            if ($tempList->[$j] !~ m/current\.txt$/ && $tempList->[$j] =~ m/\/([^\/]+)$/) {
                push(@{$list},$owners->[$i].".".$1);
            }
        }
    }
    return $list;
}

1;
