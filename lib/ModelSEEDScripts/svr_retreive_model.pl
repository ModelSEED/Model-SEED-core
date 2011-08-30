use strict;
use Data::Dumper;
use Carp;
use SeedUtils;
use FBAMODELserver;

#
# This is a SAS Component
#

=head1 svr_retreive_model

Retrieves reaction data for the selected metabolic model

------
Example: svr_retreive_model Seed83333.1 -u username -p password

Produces a * column table of data for reactions included in a genome-scale metabolic model.

------

=cut

my $mdlObject = FBAMODELserver->new();
my $usage = "usage: svr_retreive_model [model id]";
my $arguments = {-m => "",-u => "",-p => ""};
while ($ARGV[0]) {
    my $currentArg = shift @ARGV;
    if (!defined($arguments->{$currentArg})) {
		print STERR "Argument ".$currentArg." not recognized\n";
	} else {
		$arguments->{$currentArg} = shift @ARGV;
	}
}
my $input = {-abbrev_eq => 1,-id_eq => 1,-direction=>0,-compartment=>0};
if (defined($arguments->{-m}) && length($arguments->{-m}) > 0) {
	$input->{id} = $arguments->{-m};
}
if (defined($arguments->{-u}) && length($arguments->{-u}) > 0) {
	$input->{user} = $arguments->{-u};
	$input->{password} = $arguments->{-p};
}
#If no model was provided, we print data on all available models
if (!defined($arguments->{-m}) || length($arguments->{-m}) == 0) {
	print "No model selected. Select model as follows: \"svr_retreive_model.cmd -m Seed83333.1\". Here is a list of available models:\n";
	my $result = $mdlObject->get_model_id_list($input);
	if (defined($result->[0])) {
		$input->{id} = $result;
		$result = $mdlObject->get_model_data($input);
		if (defined($result->{error})) {
			print STDERR $result->{error}."\n";
		} else {
			my @models = keys(%{$result});
			print "Model ID\tGenome ID\tGenome name\n";
			for (my $i=0; $i < @models; $i++) {
				print $models[$i]."\t";
				if (defined($result->{$models[$i]}->{Genome})) {
					print $result->{$models[$i]}->{Genome};
				}
				print "\t";
				if (defined($result->{$models[$i]}->{Name})) {
					print $result->{$models[$i]}->{Name};
				}
				print "\n";
			}
		}
	} elsif (defined($result->{error})) {
		print STDERR $result->{error}."\n";
	}
}
#If model was provided, we obtain data and print it to screen
my $result = $mdlObject->get_model_reaction_data($input);
if (defined($result->{data}->[0])) {
	print join("\t",@{$result->{headings}})."\n";
	for (my $i=0; $i < @{$result->{data}}; $i++) {
		for (my $j=0; $j < @{$result->{headings}}; $j++) {
			if ($j > 0) {
				print "\t";
			}
			if (defined($result->{data}->[$i]->{$result->{headings}->[$j]}->[0])) {
				print join("|",@{$result->{data}->[$i]->{$result->{headings}->[$j]}});
			}
		}
		print "\n";
	}
} elsif (defined($result->{error})) {
	print STDERR $result->{error}."\n";
}