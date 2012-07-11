use strict;
use ModelSEED::Interface::workspace;
use ModelSEED::utilities;
package ModelSEED::Interface::interface;

my $commandapi;
my $workspace;
my $interfaceHash;
my $environment;

=head3 ENVIRONMENTFILE
Definition:
	void ModelSEED::Interface::interface::ENVIRONMENTFILE(string newenvironment);
Description:
=cut
sub ENVIRONMENTFILE {
	my ($input) = @_;
	if (defined($input)) {
		$interfaceHash->{ENVIRONMENTFILE} = $input;
	}
	if (!defined($interfaceHash->{ENVIRONMENTFILE})) {
		$interfaceHash->{ENVIRONMENTFILE} = ModelSEED::Interface::interface::MODELSEEDDIRECTORY()."/config/environment.dat";
	}
	return $interfaceHash->{ENVIRONMENTFILE};	
}
=head3 LOADENVIRONMENT
Definition:
	void ModelSEED::Interface::interface::LOADENVIRONMENT({
		filename => undef
	});
Description:
=cut
sub LOADENVIRONMENT {
	my ($args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{});
	if (!-e ModelSEED::Interface::interface::ENVIRONMENTFILE()) {
		if (defined($ENV{FIGMODEL_USER}) && defined($ENV{FIGMODEL_PASSWORD})) {
			my $workspace = "default";
			if (-e ModelSEED::Interface::interface::WORKSPACEDIRECTORY()."/".$ENV{FIGMODEL_USER}."/current.txt") {
				my $data = ModelSEED::utilities::LOADFILE(ModelSEED::Interface::interface::WORKSPACEDIRECTORY()."/".$ENV{FIGMODEL_USER}."/current.txt");
				$workspace = $data->[0];
			}
			$environment = {
				USERNAME => $ENV{FIGMODEL_USER},
				PASSWORD => $ENV{FIGMODEL_PASSWORD},
				REGISTEREDSEED => {},
				SEED => "local",
				LASTERROR => "NONE"
			};
			ModelSEED::Interface::interface::SAVEENVIRONMENT();
			my $data = ModelSEED::utilities::LOADFILE(ModelSEED::Interface::interface::BOOTSTRAPFILE());
			my $newData;
			for (my $i=0; $i < @{$data};$i++) {
				#if ($data->[$i] !~ m/FIGMODEL_PASSWORD/ && $data->[$i] !~ m/FIGMODEL_USER/) {
					push(@{$newData},$data->[$i]);
				#}
			}
			ModelSEED::utilities::PRINTFILE(ModelSEED::Interface::interface::ENVIRONMENTFILE(),$newData);
		} else {
			ModelSEED::utilities::ERROR("Environment file ".ModelSEED::Interface::interface::ENVIRONMENTFILE()." not found!");	
		}
	}
	my $data = ModelSEED::utilities::LOADFILE(ModelSEED::Interface::interface::ENVIRONMENTFILE());
	$environment->{REGISTEREDSEED} = {};
	for (my $i=1; $i < @{$data}; $i++) {
		my $array = [split(/\t/,$data->[$i])];
		if (defined($array->[1]) && $array->[0] eq "REGISTEREDSEED" && $array->[1] ne "NONE") {
			my $seedarray = [split(/;/,$array->[1])];
			for (my $j=0; $j < @{$seedarray}; $j++) {
				if ($seedarray->[$j] =~ m/^([^\:]+):(.+)$/) {
					$environment->{REGISTEREDSEED}->{$1} = $2;
				}
			}
		} elsif (defined($array->[1]) && $array->[0] ne "REGISTEREDSEED") {
			$environment->{$array->[0]} = $array->[1];
		}
	}
	if (!defined(ModelSEED::Interface::interface::USERNAME())) {
		ModelSEED::Interface::interface::SWITCHUSER("public","public")	
	}
}
=head3 SAVEENVIRONMENT
Definition:
	void ModelSEED::Interface::interface::SAVEENVIRONMENT({
		filename => undef
	});
Description:
=cut
sub SAVEENVIRONMENT {
	my ($args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{});
	my $variables = ["USERNAME","PASSWORD","SEED","LASTERROR"];
	my $output = ["SETTING\tVALUE"];
	for (my $i=0; $i < @{$variables}; $i++) {
		push(@{$output},$variables->[$i]."\t".ModelSEED::Interface::interface::ENVIRONMENT()->{$variables->[$i]});
	}
	my $env = ModelSEED::Interface::interface::ENVIRONMENT();
	my $seeddata = "NONE";
	if (defined(ModelSEED::Interface::interface::REGISTEREDSEED()) && ref(ModelSEED::Interface::interface::REGISTEREDSEED()) eq "HASH" && keys(%{ModelSEED::Interface::interface::REGISTEREDSEED()}) > 0) {
		foreach my $seedid (keys(%{ModelSEED::Interface::interface::REGISTEREDSEED()})) {
			if ($seeddata eq "NONE") {
				$seeddata = $seedid.":".ModelSEED::Interface::interface::REGISTEREDSEED()->{$seedid};
			} else {
				$seeddata .= ";".$seedid.":".ModelSEED::Interface::interface::REGISTEREDSEED()->{$seedid};
			}
		}
	}
	push(@{$output},"REGISTEREDSEED\t".$seeddata);
	ModelSEED::utilities::PRINTFILE(ModelSEED::Interface::interface::ENVIRONMENTFILE(),$output);
}
=head3 ENVIRONMENT
Definition:
	void ModelSEED::Interface::interface::ENVIRONMENT({});
Description:
=cut
sub ENVIRONMENT {
	my ($input) = @_;
	if (defined($input)) {
		$environment = $input;
	}
	if (!defined($environment)) {
		ModelSEED::Interface::interface::LOADENVIRONMENT({});
	}
	return $environment;
}
=head3 USERNAME
Definition:
	string = ModelSEED::Interface::interface::USERNAME();
Description:	
=cut
sub USERNAME {
	my ($input) = @_;
	if (defined($input)) {
		ModelSEED::Interface::interface::ENVIRONMENT()->{USERNAME} = $input;
	}
	return ModelSEED::Interface::interface::ENVIRONMENT()->{USERNAME};
}
=head3 PASSWORD
Definition:
	string = ModelSEED::Interface::interface::PASSWORD();
Description:	
=cut
sub PASSWORD {
	my ($input) = @_;
	if (defined($input)) {
		ModelSEED::Interface::interface::ENVIRONMENT()->{PASSWORD} = $input;
	}
	return ModelSEED::Interface::interface::ENVIRONMENT()->{PASSWORD};
}
=head3 SWITCHUSER
Definition:
	string = ModelSEED::Interface::interface::SWITCHUSER();
Description:	
=cut
sub SWITCHUSER {
	my ($username,$password) = @_;
	if (ModelSEED::Interface::interface::USERNAME() ne $username) {
		ModelSEED::Interface::interface::USERNAME($username);
		ModelSEED::Interface::interface::PASSWORD($password);
		ModelSEED::Interface::interface::CREATEWORKSPACE();
		ModelSEED::Interface::interface::SAVEENVIRONMENT();
	}
}
=head3 LASTERROR
Definition:
	string = ModelSEED::Interface::interface::LASTERROR();
Description:	
=cut
sub LASTERROR {
	my ($input) = @_;
	if (defined($input)) {
		ModelSEED::Interface::interface::ENVIRONMENT()->{LASTERROR} = $input;
	}
	return ModelSEED::Interface::interface::ENVIRONMENT()->{LASTERROR};
}
=head3 SEED
Definition:
	string = ModelSEED::Interface::interface::SEED();
Description:	
=cut
sub SEED {
	my ($input) = @_;
	if (defined($input)) {
		ModelSEED::Interface::interface::ENVIRONMENT()->{SEED} = $input;
	}
	return ModelSEED::Interface::interface::ENVIRONMENT()->{SEED};
}
=head3 REGISTEREDSEED
Definition:
	string = ModelSEED::Interface::interface::REGISTEREDSEED();
Description:	
=cut
sub REGISTEREDSEED {
	my ($input) = @_;
	if (defined($input)) {
		ModelSEED::Interface::interface::ENVIRONMENT()->{REGISTEREDSEED} = $input;
	}
	return ModelSEED::Interface::interface::ENVIRONMENT()->{REGISTEREDSEED};
}
=head3 WORKSPACE
Definition:
	string = ModelSEED::Interface::interface::WORKSPACE();
Description:	
=cut
sub WORKSPACE {
	my ($input) = @_;
	if (defined($input)) {
		$workspace = $input;
	}
	if (!defined($workspace)) {
		ModelSEED::Interface::interface::CREATEWORKSPACE();
	}
	return $workspace;
}
=head3 CREATEWORKSPACE
Definition:
	void ModelSEED::Interface::interface::CREATEWORKSPACE({
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
		owner => ModelSEED::Interface::interface::USERNAME(),
		rootDirectory => ModelSEED::Interface::interface::WORKSPACEDIRECTORY(),
		binDirectory => ModelSEED::Interface::interface::BINDIRECTORY(),
		clear => 0,
		copy => undef
	});
	$workspace = ModelSEED::Interface::workspace->new($args);
}
=head3 COMMANDAPI
Definition:
	ModelSEED::Interface::workspace = ModelSEED::Interface::interface::COMMANDAPI();
Description:	
=cut
sub COMMANDAPI {
	my ($input) = @_;
	if (defined($input)) {
		$commandapi = $input;
	}
	if (!defined($commandapi)) {
		ModelSEED::Interface::interface::CREATECOMMANDAPI();
	}
	return $commandapi;
}
=head3 CREATECOMMANDAPI
Definition:
	void ModelSEED::Interface::interface::CREATECOMMANDAPI({
		seed => local
	});
Description:	
=cut
sub CREATECOMMANDAPI {
	my ($args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
		seed => ModelSEED::Interface::interface::SEED()
	});
	if ($args->{seed} eq "local") {
		require "ModelSEED/ServerBackends/ModelSEEDCommandAPI.pm";
		ModelSEED::Interface::interface::COMMANDAPI(ModelSEED::ServerBackends::ModelSEEDCommandAPI->new());			
	} else {
		require "ModelSEED/ModelSEEDClients/ModelSEEDCommandAPIClient.pm";
		ModelSEED::Interface::interface::COMMANDAPI(ModelSEED::ModelSEEDClients::ModelSEEDCommandAPIClient->new({url => ModelSEED::Interface::interface::REGISTEREDSEED()->{$args->{seed}}}));
	}
}
=head3 BOOTSTRAPFILE
Definition:
	string = ModelSEED::Interface::interface::BOOTSTRAPFILE();
Description:	
=cut
sub BOOTSTRAPFILE {
	my ($input) = @_;
	if (defined($input)) {
		$interfaceHash->{_bootstrapfile} = $input;
	} 
	if (!defined($interfaceHash->{_bootstrapfile})) {
		$interfaceHash->{_bootstrapfile} = ModelSEED::Interface::interface::MODELSEEDDIRECTORY()."/config/ModelSEEDbootstrap.pm";
	}
	return $interfaceHash->{_bootstrapfile};
}
=head3 LOGDIRECTORY
Definition:
	string = ModelSEED::Interface::interface::LOGDIRECTORY();
Description:	
=cut
sub LOGDIRECTORY {
	my ($input) = @_;
	if (defined($input)) {
		$interfaceHash->{_logdirectory} = $input;
	} 
	if (!defined($interfaceHash->{_logdirectory})) {
		$interfaceHash->{_logdirectory} = ModelSEED::Interface::interface::MODELSEEDDIRECTORY()."/logs/";
	}
	return $interfaceHash->{_logdirectory};
}
=head3 BINDIRECTORY
Definition:
	string = ModelSEED::Interface::interface::BINDIRECTORY();
Description:	
=cut
sub BINDIRECTORY {
	my ($input) = @_;
	if (defined($input)) {
		$interfaceHash->{_bindirectory} = $input;
	} 
	if (!defined($interfaceHash->{_bindirectory})) {
		$interfaceHash->{_bindirectory} = ModelSEED::Interface::interface::MODELSEEDDIRECTORY()."/bin/";
	}
	return $interfaceHash->{_bindirectory};
}
=head3 WORKSPACEDIRECTORY
Definition:
	string = ModelSEED::Interface::interface::WORKSPACEDIRECTORY();
Description:	
=cut
sub WORKSPACEDIRECTORY {
	my ($input) = @_;
	if (defined($input)) {
		$interfaceHash->{_workspacedirectory} = $input;
	} 
	if (!defined($interfaceHash->{_workspacedirectory})) {
		$interfaceHash->{_workspacedirectory} = ModelSEED::Interface::interface::MODELSEEDDIRECTORY()."/workspace/";
	}
	return $interfaceHash->{_workspacedirectory};
}
=head3 MODELSEEDDIRECTORY
Definition:
	string = ModelSEED::Interface::interface::MODELSEEDDIRECTORY();
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
	[string] = ModelSEED::Interface::interface::PROCESSIDLIST({
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
		} elsif (-e ModelSEED::Interface::interface::WORKSPACE()->directory().$args->{input}) {
			$output = ModelSEED::utilities::LOADFILE(ModelSEED::Interface::interface::WORKSPACE()->directory().$args->{input},"");
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