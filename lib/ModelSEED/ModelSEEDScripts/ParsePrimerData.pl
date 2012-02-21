use strict;
use lib 'c:/Code/Model-SEED-core/lib';
use ModelSEED::utilities;

my $data = ModelSEED::utilities::LOADFILE("C:/Code/Model-SEED-core/workspace/chenry/minibsub/PrimerData.txt");
my $primerHash;
my $output = ["Interval\tStart\tStop\tTime\tP1\tP2\tP3\tP4\tP5\tP6"];
for (my $i=0; $i < @{$data}; $i++) {
	if ($data->[$i] =~ m/Interval:\s\[(\d+),\s(\d+)\]\tkoI(\d+)\t([^\t]+)/) {
		my $line = "i".
		
		$3."\t".$1."\t".$2."\t".$4;
		for (my $j=0; $j < 6; $j++) {
			$i++;
			my $temp = [split(/\t/,$data->[$i])];
			if (defined($temp->[8])) {
				$line .= "\t".$temp->[8];
			}
		}
		push(@{$output},$line);
	}
}
my $data = ModelSEED::utilities::PRINTFILE("C:/Code/Model-SEED-core/workspace/chenry/minibsub/RefinedPrimerData.txt",$output);