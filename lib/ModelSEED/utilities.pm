use strict;
use warnings;
use Carp qw(cluck);
use Data::Dumper;
use File::Temp qw(tempfile);
use File::Path;
use File::Copy::Recursive;
#use FIGMODELTable;
package ModelSEED::utilities;

=head3 ARGS
Definition:
	ARGS->({}:arguments,[string]:mandatory arguments,{}:optional arguments);
Description:
	Processes arguments to authenticate users and perform other needed tasks
=cut
sub ARGS {
	my ($args,$mandatoryArguments,$optionalArguments) = @_;
	if (defined($mandatoryArguments)) {
		for (my $i=0; $i < @{$mandatoryArguments}; $i++) {
			if (!defined($args->{$mandatoryArguments->[$i]})) {
				push(@{$args->{_error}},$mandatoryArguments->[$i]);
			}
		}
	}
	ModelSEED::utilities::ERROR("Mandatory arguments ".join("; ",@{$args->{_error}})." missing. Usage:".ModelSEED::utilities::USAGE($mandatoryArguments,$optionalArguments,$args)) if (defined($args->{_error}));
	if (defined($optionalArguments)) {
		foreach my $argument (keys(%{$optionalArguments})) {
			if (!defined($args->{$argument})) {
				$args->{$argument} = $optionalArguments->{$argument};
			}
		}	
	}
	return $args;
}

=head3 USAGE
Definition:
	string = ModelSEED::utilities::USAGE([]:madatory arguments,{}:optional arguments);
Description:
	Prints the usage for the current function call.
=cut
sub USAGE {
	my ($mandatoryArguments,$optionalArguments,$args) = @_;
	my $current = 1;
	my @calldata = caller($current);
	while ($calldata[3] eq "ModelSEED::utilities::ARGS" || $calldata[3] eq "ModelSEED::FIGMODEL::process_arguments") {
		$current++;
		@calldata = caller($current);
	}
	my $call = $calldata[3];
	my $usage = "";
	if (defined($mandatoryArguments)) {
		for (my $i=0; $i < @{$mandatoryArguments}; $i++) {
			if (length($usage) > 0) {
				$usage .= "/";	
			}
			$usage .= $mandatoryArguments->[$i];
			if (defined($args)) {
				$usage .= " => ";
				if (defined($args->{$mandatoryArguments->[$i]})) {
					$usage .= $args->{$mandatoryArguments->[$i]};
				} else {
					$usage .= " => ?";
				}
			}
		}
	}
	if (defined($optionalArguments)) {
		my $optArgs = [keys(%{$optionalArguments})];
		for (my $i=0; $i < @{$optArgs}; $i++) {
			if (length($usage) > 0) {
				$usage .= "/";	
			}
			$usage .= $optArgs->[$i]."(".$optionalArguments->{$optArgs->[$i]}.")";
			if (defined($args)) {
				$usage .= " => ";
				if (defined($args->{$optArgs->[$i]})) {
					$usage .= $args->{$optArgs->[$i]};
				} else {
					$usage .= " => ".$optionalArguments->{$optArgs->[$i]};
				}
			}
		}
	}
	return $call."{".$usage."}";
}

=head3 ERROR
Definition:
	void ModelSEED::utilities::ERROR();
Description:	
=cut
sub ERROR {	
	my ($message) = @_;
    $message = "\"\"$message\"\"";
	Carp::confess($message);
}
=head3 USEERROR
Definition:
	void ModelSEED::utilities::USEERROR();
Description:	
=cut
sub USEERROR {	
	my ($message) = @_;
	print STDERR "\n".$message."\n";
	print STDERR "Critical error. Discontinuing current operation!\n";
	exit();
}
=head3 USEWARNING
Definition:
	void ModelSEED::utilities::USEWARNING();
Description:	
=cut
sub USEWARNING {	
	my ($message) = @_;
	print STDERR "\n".$message."\n\n";
}
=head3 WARNING
Definition:
	void ModelSEED::utilities::WARNING();
Description:	
=cut
sub WARNING {	
	my ($message) = @_;
	Carp::cluck($message);
}

=head3 TIMESTAMP
Definition:
	TIMESTAMP = ModelSEED::utilities::TIMESTAMP();
Description:	
=cut
sub TIMESTAMP {
	my ($sec,$min,$hour,$day,$month,$year) = gmtime(time());
	$year += 1900;
	$month += 1;
	return $year."-".$month."-".$day.' '.$hour.':'.$min.':'.$sec;
}

=head3 PRINTFILE
Definition:
	void ModelSEED::utilities::PRINTFILE();
Description:	
=cut
sub PRINTFILE {
    my ($filename,$arrayRef) = @_;
    open ( my $fh, ">", $filename) || ModelSEED::utilities::ERROR("Failure to open file: $filename, $!");
    foreach my $Item (@{$arrayRef}) {
    	print $fh $Item."\n";
    }
    close($fh);
}

=head3 LOADFILE
Definition:
	void ModelSEED::utilities::LOADFILE();
Description:	
=cut
sub LOADFILE {
    my ($filename) = @_;
    my $DataArrayRef = [];
    open (INPUT, "<", $filename) || ModelSEED::utilities::ERROR("Couldn't open $filename: $!");
    while (my $Line = <INPUT>) {
        chomp($Line);
        $Line =~ s/\r//;
        push(@{$DataArrayRef},$Line);
    }
    close(INPUT);
    return $DataArrayRef;
}

=head3 MAKEXLS
Definition:
	{} = ModelSEED::utilities::MAKEXLS({
		filename => string,
		sheetnames => [string],
		sheetdata => [FIGMODELTable]
	});
Description:
=cut
sub MAKEXLS {
    my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["filename","sheetnames","sheetdata"],{});
    my $workbook = $args->{filename};
    for(my $i=0; $i<@{$args->{sheetdata}}; $i++) {
        $workbook = $args->{sheetdata}->[$i]->add_as_sheet($args->{sheetnames}->[$i],$workbook);
    }
    $workbook->close();
    return;
}

=head3 BUILDCOMMANDLINE
Definition:
	string = ModelSEED::utilities::BUILDCOMMANDLINE({
		function => string:function name,
		arguments => {}
	});
Description:
	This function converts the job specifications into a ModelDriver command
Example:
=cut
sub BUILDCOMMANDLINE {
	my ($args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["function"],{
		arguments => {},
		nohup => 0
	});
	my $command = $ENV{"MODEL_SEED_CORE"}."/bin/ModelDriver ".$args->{function};
	foreach my $argument (keys(%{$args->{arguments}})) {
		$command .= " -".$argument." ".$args->{arguments}->{$argument};
	}
	if ($args->{nohup} == 1) {
		$command = "nohup ".$command." &";
	}
	return $command;
}

=head3 RUNMODELDRIVER
Definition:
	string = ModelSEED::utilities::RUNMODELDRIVER({
		function => string:function name,
		arguments => {},
		nohup => 0/1
	});
Description:
	This function converts the job specifications into a ModelDriver command and runs it
Example:
=cut
sub RUNMODELDRIVER {
	my ($args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["function"],{
		arguments => {},
		nohup => 0
	});
	my $command = ModelSEED::utilities::BUILDCOMMANDLINE($args);
	print "Now running:".$command."!\n";
	system($command);
}

=head3 MODELSEEDCOREDIR
Definition:
	string = ModelSEED::utilities::MODELSEEDCOREDIR();
Description:
	This function converts the job specifications into a ModelDriver command and runs it
Example:
=cut
sub MODELSEEDCOREDIR {
	return $ENV{MODEL_SEED_CORE};
}

=head3 MODELSEEDCORE
Definition:
	string = ModelSEED::utilities::MODELSEEDCORE();
Description:
	This function converts the job specifications into a ModelDriver command and runs it
Example:
=cut
sub MODELSEEDCORE {
	return $ENV{MODEL_SEED_CORE};
}

=head3 GLPK
Definition:
	string = ModelSEED::utilities::GLPK();
Description:
	Returns location of glpk executable
Example:
=cut
sub GLPK {
	return $ENV{GLPK};
}

=head3 CPLEX
Definition:
	string = ModelSEED::utilities::CPLEX();
Description:
	Returns location of cplex executable
Example:
=cut
sub CPLEX {
	return $ENV{CPLEX};
}

1;
