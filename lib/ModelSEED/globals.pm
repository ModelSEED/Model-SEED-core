use strict;
use warnings;
use Carp qw(cluck);
use Data::Dumper;
use File::Temp qw(tempfile);
use File::Path;
use File::Copy::Recursive;
package ModelSEED::globals;

=head3 ModelSEED::globals::ARGS
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
	ModelSEED::globals::ERROR("Mandatory arguments ".join("; ",@{$args->{_error}})." missing. Usage:".ModelSEED::globals::USAGE($mandatoryArguments,$optionalArguments,$args)) if (defined($args->{_error}));
	if (defined($optionalArguments)) {
		foreach my $argument (keys(%{$optionalArguments})) {
			if (!defined($args->{$argument})) {
				$args->{$argument} = $optionalArguments->{$argument};
			}
		}	
	}
	return $args;
}

=head3 ModelSEED::globals::USAGE
Definition:
	string = ModelSEED::globals::USAGE([]:madatory arguments,{}:optional arguments);
Description:
	Prints the usage for the current function call.
=cut
sub USAGE {
	my ($mandatoryArguments,$optionalArguments,$args) = @_;
	my $current = 1;
	my @calldata = caller($current);
	while ($calldata[3] eq "ModelSEED::globals::ARGS" || $calldata[3] eq "ModelSEED::FIGMODEL::process_arguments") {
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

sub ERROR {	
	my ($message) = @_;
    $message = "\"\"$message\"\"";
	Carp::confess($message);
}

sub WARNING {	
	my ($message) = @_;
	Carp::cluck($message);
}

=head3 TIMESTAMP
Definition:
	TIMESTAMP = ModelSEED::globals::TIMESTAMP();
Description:	
=cut
sub TIMESTAMP {
	my ($sec,$min,$hour,$day,$month,$year) = gmtime(time());
	$year += 1900;
	$month += 1;
	return $year."-".$month."-".$day.' '.$hour.':'.$min.':'.$sec;
}

sub PRINTFILE {
    my ($filename,$arrayRef) = @_;
    open ( my $fh, ">", $filename) || ModelSEED::globals::ERROR("Failure to open file: $filename, $!");
    foreach my $Item (@{$arrayRef}) {
    	print $fh $Item."\n";
    }
    close($fh);
}

sub LOADFILE {
    my ($filename) = @_;
    my $DataArrayRef = [];
    open (INPUT, "<", $filename) || ModelSEED::globals::ERROR("Couldn't open $filename: $!");
    while (my $Line = <INPUT>) {
        chomp($Line);
        push(@{$DataArrayRef},$Line);
    }
    close(INPUT);
    return $DataArrayRef;
}

=head3 BUILDCOMMANDLINE
Definition:
	string = BUILDCOMMANDLINE({
		function => string:function name,
		arguments => {}
	});
Description:
	This function converts the job specifications into a ModelDriver command
Example:
=cut
sub BUILDCOMMANDLINE {
	my ($args) = @_;
	$args = ModelSEED::globals::ARGS($args,["function"],{
		arguments => {},
		nohup => 0
	});
	my $command = $ENV{"MODEL_SEED_CORE"}."bin/ModelDriver ".$args->{function};
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
	string = RUNMODELDRIVER({
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
	$args = ModelSEED::globals::ARGS($args,["function"],{
		arguments => {},
		nohup => 0
	});
	my $command = ModelSEED::globals::BUILDCOMMANDLINE($args);
	print "Now running:".$command."!\n";
	system($command);
}

=head3 PRINTOBJECT
Definition:
	string = PRINTOBJECT({
		data => {}:object dump,
		filename => string:filename
	});
Description:
	This function prints a serialized moose object to a human-editable file
Example:
=cut
sub PRINTOBJECT {
	my ($args) = @_;
	$args = ModelSEED::globals::ARGS($args,["data","filename"],{});
	if (!defined($args->{data}->{attributes})) {
		ModelSEED::globals::ERROR("Data to be printed must contain an attributes hash!");
	}
	my $ordered;
	foreach my $attribute (keys(%{$args->{data}->{attributes}})) {
		push(@{$ordered},[$attribute,$args->{data}->{attributes}->{$attribute}]);
	}
	@{$ordered} = sort { $a-> [1] <=> $b->[1] } @{$ordered};
	my $output;
	for (my $i=0; $i < @{$ordered}; $i++) {
		if (ref($args->{data}->{$ordered->[$i]->[0]}) eq "") {
			push(@{$output},$ordered->[$i]->[0].":\t".$args->{data}->{$ordered->[$i]->[0]});
		} elsif (ref($args->{data}->{$ordered->[$i]->[0]}) eq "ARRAY") {
			if (ref($args->{data}->{$ordered->[$i]->[0]}->[0]) eq "SCALAR") {
				push(@{$output},$ordered->[$i]->[0].":\t".join("|",@{$args->{data}->{$ordered->[$i]->[0]}}));
			} elsif (ref($args->{data}->{$ordered->[$i]->[0]}->[0]) eq "HASH") {
				if (defined($args->{data}->{$ordered->[$i]->[0]}->[0]->{attributes})) {
					push(@{$output},$ordered->[$i]->[0]."{");
					my $orderedTwo;
					foreach my $attribute (keys(%{$args->{data}->{$ordered->[$i]->[0]}->[0]->{attributes}})) {
						push(@{$orderedTwo},[$attribute,$args->{data}->{$ordered->[$i]->[0]}->[0]->{attributes}->{$attribute}]);
					}
					@{$orderedTwo} = sort { $a->[1] cmp $b->[1] } @{$orderedTwo};
					my $line = "";
					for (my $k=0; $k < @{$orderedTwo}; $k++) {
						if ($k > 0) {
							$line .= "\t";	
						}
						$line .= $orderedTwo->[$k]->[0];
					}
					push(@{$output},join("\t",$line));
					for (my $j=0; $j < @{$args->{data}->{$ordered->[$i]->[0]}}; $j++) {
						$line = "";
						for (my $k=0; $k < @{$orderedTwo}; $k++) {
							if ($k > 0) {
								$line .= "\t";	
							}
							if (ref($args->{data}->{$ordered->[$i]->[0]}->[$j]->{$orderedTwo->[$k]->[0]}) eq "") {
								$line .= $args->{data}->{$ordered->[$i]->[0]}->[$j]->{$orderedTwo->[$k]->[0]};
							} else {
								print "Reference:".ref($args->{data}->{$ordered->[$i]->[0]}->[$j]->{$orderedTwo->[$k]->[0]})."\n";
							}
						}
						push(@{$output},join("\t",$line));
					}
					push(@{$output},"}");
					
				}
			}
		} elsif (ref($args->{data}->{$ordered->[$i]->[0]}) eq "HASH") {
			push(@{$output},$ordered->[$i]->[0].":");
		} else {
			print "Reference:".ref($args->{data}->{$ordered->[$i]->[0]})."\n";
		}
	}
	ModelSEED::globals::PRINTFILE($args->{filename},$output);
}

1;
