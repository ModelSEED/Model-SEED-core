#!/usr/bin/perl -w
use strict;
use ModelSEED::utilities;

my $intervalGenesFile = "C:/Code/Model-SEED-core/data/IntervalGenes.txt";
my $intdata = ModelSEED::utilities::LOADFILE($intervalGenesFile);
my $modelGenes = "C:/Code/Model-SEED-core/data/ModelGenes.txt";
my $mdlgenes = ModelSEED::utilities::LOADFILE($modelGenes);
my $mdlGeneHash;
my $intGeneHash;
for (my $i=1; $i <@{$mdlgenes}; $i++) {
	my $array = [split(/\t/,$mdlgenes->[$i])];
	if (defined($array->[0]) && $array->[0] =~ /peg\.\d+/) {
		$mdlGeneHash->{$array->[0]} = 1;
	}
}
for (my $i=1; $i <@{$intdata}; $i++) {
	my $array = [split(/\t/,$intdata->[$i])];
	if (defined($array->[2]) && $array->[0] =~ /(i\d+)/ && $array->[2] eq "LB") {
		my $newarray = [split(/,/,$array->[1])];
		for (my $j=0; $j <@{$newarray}; $j++) {
			if (defined($mdlGeneHash->{$newarray->[$j]})) {
				$intGeneHash->{$array->[0]}->{$newarray->[$j]} = 1;
			}
		}
	}
}
my $output = [];
foreach my $int (keys(%{$intGeneHash})) {
	push(@{$output},$int."\t".join(",",keys(%{$intGeneHash->{$int}})));
}
ModelSEED::utilities::PRINTFILE("C:/Code/Model-SEED-core/data/MetabolicIntervalGenes.txt",$output);