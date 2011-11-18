#!/usr/bin/perl

use strict;
$|=1;

my $SourcePath = $ARGV[0];
my $DestinationPath = $ARGV[1];
my $MarvinBeansPath = $ARGV[2];
$MarvinBeansPath .= "bin/cxcalc";

if(!$SourcePath || !-d $SourcePath || !$DestinationPath || !-d $DestinationPath || !$MarvinBeansPath){
    usage();
    exit(0);
}

if(!-f $MarvinBeansPath){
    usage();
    print STDERR "Cannot find cxcalc executable, double-check path for MarvinBeans software:\n".$MarvinBeansPath."\n";
    exit(0);
}

my $CombinedFilename = $DestinationPath."Combined.sdf";
my @Files = glob($SourcePath."*.mol");


open (COMBINED, ">$CombinedFilename");
foreach my $Filename (@Files) {
	if (open (MOLFILE, "<$Filename")) {
		my $Line = <MOLFILE>;
		chomp($Line);
		$Filename =~ s/.*[\/\\](.*)/$1/;
		print COMBINED $Line,"|",$Filename,"\n";
		while ($Line = <MOLFILE>) {
			print COMBINED $Line;
			if (index($Line,"M  END") != -1) {
				last;
			}
		}
		close (MOLFILE);		
	}
	print COMBINED '$$$$',"\n";
}
close (COMBINED);
#exit;
my $Command = '/home/chenry/Software/MarvinBeans/bin/cxcalc -N hi majorms -H 7 -f mol:-a '.$DestinationPath.'Combined.sdf > '.$DestinationPath.'ChargeOutput.txt';
system($Command);

$CombinedFilename = $DestinationPath."ChargeOutput.txt";
open (COMBINED, "<$CombinedFilename");
while(my $Line = <COMBINED>) {
	if (length($Line) == 0) {
		last;
	}
	chomp($Line);
	my ($Formula,$Filename) = split /\|/ , $Line;
	$Filename = $DestinationPath.$Filename;
	open (MOLFILE, ">$Filename");
	print MOLFILE $Formula,"\n";
	while($Line = <COMBINED>) {
		print MOLFILE $Line;
		if (index($Line,"M  END") != -1) {
			last;
		}
	}
	close (MOLFILE);
}
close (COMBINED);

unlink($DestinationPath."Combined.sdf");
unlink($DestinationPath."ChargeOutput.txt");

sub usage {
    print "./ChargeMolfiles <directory of mol files> <Directory for output files> <Path for MarvinBeans Software (ie ~/Software/MarvinBeans/)>\n";
}
