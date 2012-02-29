use strict;
use warnings;
use Carp qw(cluck);
use Data::Dumper;
use File::Temp qw(tempfile);
use File::Path;
use File::Copy::Recursive;
package ModelSEED::globals;

my $globalFIGMODEL;

sub CREATEFIGMODEL {
	my ($args) = @_;
	$globalFIGMODEL = ModelSEED::FIGMODEL->new($args);
}

sub SETFIGMODEL {
	my ($infigmodel) = @_;
	$globalFIGMODEL = $infigmodel;
}

sub GETFIGMODEL {
	return $globalFIGMODEL;
}
=head3 VALIDATEINPUT
Definition:
	Object = ModelSEED::globals::VALIDATEINPUT({
		input => string,
		type => string,
		name => string,
		attribute => string
	});
Description:	
=cut
sub VALIDATEINPUT {
	my ($args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["input","type","name"],{
		attribute => "id",
	});
	my $object = ModelSEED::globals::GETFIGMODEL()->database()->get_object($args->{type},{$args->{attribute} => $args->{input}});
	if (!defined($object)) {
		ModelSEED::utilities::ERROR("No \"".$args->{type}."\" found that matches input ".$args->{name}." \"".$args->{input}."\"");
	}
	return $object;
}
=head3 PROCESSIDLIST
Definition:
	[string] = ModelSEED::globals::PROCESSIDLIST({
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
		} elsif (-e ModelSEED::globals::GETFIGMODEL->ws()->directory().$args->{input}) {
			$output = ModelSEED::utilities::LOADFILE(ModelSEED::globals::GETFIGMOEL()->ws()->directory().$args->{input},"");
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
