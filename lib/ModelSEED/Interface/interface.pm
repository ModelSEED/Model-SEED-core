use strict;
package ModelSEED::Interface::interface;
use ModelSEED::Interface::workspace;
use ModelSEED::utilities;

my $commandapi;
my $workspace;
my $interfaceHash;

=head3 UPDATEENVIRONMENT
Definition:
	void ModelSEED::interface::UPDATEENVIRONMENT({
		
	});
Description:	
=cut
sub UPDATEENVIRONMENT {
	my ($args) = @_;
	my $data = ModelSEED::utilities::LOADFILE(ModelSEED::interface::BOOTSTRAPFILE());
    my ($addedPWD, $addedUSR) = (0,0);
	for (my $i=0; $i < @{$data};$i++) {
		if ($data->[$i] =~ m/FIGMODEL_PASSWORD/) {
			$data->[$i] = '$ENV{FIGMODEL_PASSWORD} = "'.ModelSEED::interface::PASSWORD().'";';
            $addedPWD = 1;
		}
		if ($data->[$i] =~ m/FIGMODEL_USER/) {
			$data->[$i] = '$ENV{FIGMODEL_USER} = "'.ModelSEED::interface::USERNAME().'";';
            $addedUSR = 1;
		}
	}
    if(!$addedPWD) {
		push(@{$data},'$ENV{FIGMODEL_PASSWORD} = "'.ModelSEED::interface::PASSWORD().'";');
    } 
    if(!$addedUSR) {
		push(@{$data},'$ENV{FIGMODEL_USER} = "'.ModelSEED::interface::USERNAME().'";');
    } 
	ModelSEED::utilities::PRINTFILE(ModelSEED::interface::BOOTSTRAPFILE(),$data);	
}
=head3 CREATEWORKSPACE
Definition:
	void ModelSEED::interface::CREATEWORKSPACE({
		owner => string,
		root => string,
		binDirectory => string,
		clear => 0,
		copy => undef
	});
Description:	
=cut
sub CREATEWORKSPACE {
	my ($args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
		owner => ModelSEED::interface::USERNAME(),
		root => ModelSEED::interface::WORKSPACEDIRECTORY(),
		binDirectory => ModelSEED::interface::BINDIRECTORY(),
		clear => 0,
		copy => undef
	});
	$workspace = ModelSEED::Interface::workspace->new($args);
}
=head3 SETWORKSPACE
Definition:
	void ModelSEED::interface::SETWORKSPACE(ModelSEED::interface::workspace);
Description:	
=cut
sub SETWORKSPACE {
	my ($inworkspace) = @_;
	$workspace = $inworkspace;
}
=head3 GETWORKSPACE
Definition:
	ModelSEED::interface::workspace = ModelSEED::interface::GETWORKSPACE();
Description:	
=cut
sub GETWORKSPACE {
	return $workspace;
}
=head3 GETCOMMANDAPI
Definition:
	ModelSEED::interface::workspace = ModelSEED::interface::GETCOMMANDAPI();
Description:	
=cut
sub GETCOMMANDAPI {
	return $commandapi;
}
=head3 USERNAME
Definition:
	string = ModelSEED::interface::USERNAME();
Description:	
=cut
sub USERNAME {
	my ($input) = @_;
	if (defined($input)) {
		$interfaceHash->{_username} = $input;
	} 
	if (!defined($interfaceHash->{_username})) {
		if (defined($ENV{FIGMODEL_USER})) {
			$interfaceHash->{_username} = $ENV{FIGMODEL_USER};
		} else {
			$interfaceHash->{_username} = "public";
		}
	}
	return $interfaceHash->{_username};
}
=head3 PASSWORD
Definition:
	string = ModelSEED::interface::PASSWORD();
Description:	
=cut
sub PASSWORD {
	my ($input) = @_;
	if (defined($input)) {
		$interfaceHash->{_password} = $input;
	} 
	if (!defined($interfaceHash->{_password})) {
		if (defined($ENV{FIGMODEL_PASSWORD})) {
			$interfaceHash->{_password} = $ENV{FIGMODEL_PASSWORD};
		} else {
			$interfaceHash->{_password} = "public";
		}
	}
	return $interfaceHash->{_password};
}
=head3 BOOTSTRAPFILE
Definition:
	string = ModelSEED::interface::BOOTSTRAPFILE();
Description:	
=cut
sub BOOTSTRAPFILE {
	my ($input) = @_;
	if (defined($input)) {
		$interfaceHash->{_bootstrapfile} = $input;
	} 
	if (!defined($interfaceHash->{_bootstrapfile})) {
		$interfaceHash->{_bootstrapfile} = ModelSEED::interface::MODELSEEDDIRECTORY()."/config/ModelSEEDbootstrap.pm";
	}
	return $interfaceHash->{_bootstrapfile};
}
=head3 LOGDIRECTORY
Definition:
	string = ModelSEED::interface::LOGDIRECTORY();
Description:	
=cut
sub LOGDIRECTORY {
	my ($input) = @_;
	if (defined($input)) {
		$interfaceHash->{_logdirectory} = $input;
	} 
	if (!defined($interfaceHash->{_logdirectory})) {
		$interfaceHash->{_logdirectory} = ModelSEED::interface::MODELSEEDDIRECTORY()."/logs/";
	}
	return $interfaceHash->{_logdirectory};
}
=head3 BINDIRECTORY
Definition:
	string = ModelSEED::interface::BINDIRECTORY();
Description:	
=cut
sub BINDIRECTORY {
	my ($input) = @_;
	if (defined($input)) {
		$interfaceHash->{_bindirectory} = $input;
	} 
	if (!defined($interfaceHash->{_bindirectory})) {
		$interfaceHash->{_bindirectory} = ModelSEED::interface::MODELSEEDDIRECTORY()."/bin/";
	}
	return $interfaceHash->{_bindirectory};
}
=head3 WORKSPACEDIRECTORY
Definition:
	string = ModelSEED::interface::WORKSPACEDIRECTORY();
Description:	
=cut
sub WORKSPACEDIRECTORY {
	my ($input) = @_;
	if (defined($input)) {
		$interfaceHash->{_workspacedirectory} = $input;
	} 
	if (!defined($interfaceHash->{_workspacedirectory})) {
		$interfaceHash->{_workspacedirectory} = ModelSEED::interface::MODELSEEDDIRECTORY()."/workspace/";
	}
	return $interfaceHash->{_workspacedirectory};
}
=head3 MODELSEEDDIRECTORY
Definition:
	string = ModelSEED::interface::MODELSEEDDIRECTORY();
Description:	
=cut
sub MODELSEEDDIRECTORY {
	my ($input) = @_;
	if (defined($input)) {
		$interfaceHash->{_modelseeddirectory} = $input;
	} 
	if (!defined($interfaceHash->{_modelseeddirectory})) {
		$interfaceHash->{_modelseeddirectory} = $ENV{MODEL_SEED_CORE};
	}
	return $interfaceHash->{_modelseeddirectory};
}
=head3 PROCESSIDLIST
Definition:
	[string] = ModelSEED::interface::PROCESSIDLIST({
		input => string
	});
Description:	
=cut
sub PROCESSIDLIST {
	my ($args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["input"],{
		delimiter => "[,;]",
		validation => undef
	});
	my $output;
	if ($args->{input} =~ m/\.lst$/) {
		if ($args->{input} =~ m/^\// && -e $args->{input}) {	
			$output = ModelSEED::utilities::LOADFILE($args->{input},"");
		} elsif (-e ModelSEED::interface::GETWORKSPACE()->directory().$args->{input}) {
			$output = ModelSEED::utilities::LOADFILE(ModelSEED::interface::GETWORKSPACE()->directory().$args->{input},"");
		}
	} else {
		my $d = $args->{delimiter};
		$output = [split(/$d/,$args->{input})];
	}
	if (defined($args->{validation})) {
		my $v = $args->{validation};
		my $newOutput;
		for (my $i=0; $i < @{$output}; $i++) {
			if ($output->[$i] =~ m/$v/) {
				push(@{$newOutput},$output->[$i]);
			}
		}
		$output = $newOutput;
	}
	return $output;
}

1;