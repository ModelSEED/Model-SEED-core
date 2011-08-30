use strict;


use Getopt::Long;
use FBAMODELserver;
#use ModelSEED::FBAMODEL;
#use SeedEnv;
#use ExpressionDir;
#
# This is a SAS Component
#
=head1 svr_run_gene_activity_simulation
Identify gene calls that are inconsistent with model simulations.
------
Example: svr_run_gene_activity_simulation -infile GeneCalls-158878.1.txt -media Complete -output Results-158878.1.txt
------
Produces a file called "Results-158878.1.txt" with biomass, fluxes, and gene call consististency:
Label	Experiment 1
Description	pH7
Media	Complete
Model	Seed158878.1
Genome	158878.1
Fluxes	rxn00001:1.321;rxn00002:-1.321....
Biomass	4.581
peg.1	(call status)/(model status)
peg.2	on/nonmetabolic
...
------
Called options: on, off, unknown
Model options: on, off, nonmetabolic, essential, inactive, nonfunctional
------
=head2 Command-Line Options
=over 4
=item url
The URL for the Sapling server, if it is to be different from the default.
=item complete
If TRUE, only complete genomes will be returned. The default is FALSE (return all genomes).
=back
=head2 Output Format
The standard output is a file where each line contains a genome name and a genome ID.
=cut
my $usage = 'usage: svr_run_gene_activity_simulation --jobid 1549 --infile GeneCalls-158878.1.txt --genome 158878.1 --model Seed158878.1 --outfile Results-83333.1.txt --url http://www.theseed.org/ --user reviewer --password reviewer'."\n";
my $infile = '';
my $genome = '';
my $model = '';
my $outfile = '';
my $url = '';
my $user = '';
my $password = '';
my $jobid = '';
my $opted = GetOptions('jobid:s' => \$jobid,'infile:s' => \$infile,'genome:s' => \$genome,'model:s' => \$model,'outfile:s' => \$outfile,'user:s' => \$user,'url:s' => \$url,'password:s' => \$password);
if (!$opted) {
    print STDERR $usage;
    return;
}
#Checking for job ID
#my $fbamodel  = ModelSEED::FBAMODEL->new(url => $url);
my $fbamodel  = FBAMODELserver->new();
if (length($user) == 0) {
	print STDERR "Must provide a username\n";
	return;
}
if (length($password) == 0) {
	print STDERR "Must provide a password\n";
	return;
}
if (length($outfile) == 0) {
	print STDERR "Must provide an output file\n";
	return;
}
if (length($jobid) == 0) {
	#Setting default values for variables:
	if (length($infile) == 0) {
		print STDERR "Must provide an input file\n";
		return;
	}
	if (length($genome) == 0 && length($model) == 0) {
		print STDERR "Must provide a genome ID or model ID\n";
		return;
	}
	my $id = $model;
	if (length($id) == 0) {
		$id = $genome;
	}
	if (!-e $infile) {
		print STDERR "Input file ".$infile." could not be found!\n";
	    return;	
	}
	open (my $fh, "<", $infile) || die($@);
	my $input = {user => $user,password => $password,id => $id,media => [],labels => [],descriptions => [],geneCalls => {}};
	while(<$fh>) {
		chomp $_;
		my $line = $_;
		my @tempArray = split(/\t/,$line);
		if (@tempArray >= 2) {
			for (my $i=1; $i < @tempArray; $i++) {
				if ($tempArray[0] eq "Labels") {
					push(@{$input->{labels}},$tempArray[$i]);
				} elsif ($tempArray[0] eq "Descriptions") {
					push(@{$input->{descriptions}},$tempArray[$i]);
				} elsif ($tempArray[0] eq "Media") {
					if (length($tempArray[$i]) == 0) {
						$tempArray[$i] = "Complete";
					}
					push(@{$input->{media}},$tempArray[$i]);
				} else {
					if (!defined($input->{media}->[$i-1])) {
						$input->{media}->[$i-1] = "Complete";
					}
					if (!defined($input->{descriptions}->[$i-1])) {
						$input->{descriptions}->[$i-1] = "NONE";
					}
					if (!defined($input->{labels}->[$i-1])) {
						$input->{labels}->[$i-1] = "Experiment ".$i;
					}
					push(@{$input->{geneCalls}->{$tempArray[0]}},$tempArray[$i]);
				}
			}
		}
	}
	close($fh);
	my $result = $fbamodel->fba_submit_gene_activity_analysis($input);
	if (defined($result->{jobid})) {
		$jobid = $result->{jobid};
		open (OUTPUT, ">$outfile");
		print OUTPUT "Job submitted with job ID = ".$jobid.".\n
		If script halted before retrieval of results, simply rerun with following arguments:\n
		svr_run_gene_activity_simulation.cmd --jobid ".$jobid." --outfile ".$outfile." --user ".$user." --password ".$password."\n"; 
		close(OUTPUT);
	} elsif (defined($result->{error})) {
		open (OUTPUT, ">$outfile");
		print STDERR "Job failed with error ".$result->{error}."\n";
		print OUTPUT "Job failed with error ".$result->{error}."\n";	
		close(OUTPUT);
		exit(0);
	} else {
		open (OUTPUT, ">$outfile");
		print STDERR "Job failed with unknown error\n";
		print OUTPUT "Job failed with unknown error\n";	
		close(OUTPUT);
		exit(0);
	}
}
if (length($jobid) == 0) {
	open (OUTPUT, ">$outfile");
	print STDERR "No job ID available for retreival of results\n";
	print OUTPUT "No job ID available for retreival of results\n";	
	close(OUTPUT);
	exit(0);
}
my $continue = 1;
my $results;
print "Checking for results!\n";
while ($continue == 1) {
	sleep(60);
	print "Still checking for results!\n";
	$results = $fbamodel->fba_retreive_gene_activity_analysis({user => $user,password => $password,jobid=>$jobid});
	if (defined($results)) {
		if (defined($results->{error})) {
			open (OUTPUT, ">$outfile");
			print STDERR "Job failed on server with error ".$results->{error}.". Email chenry\@mcs.anl.gov with jobid ".$jobid.", error message, and input file\n";
			print OUTPUT "Job failed on server with error ".$results->{error}.". Email chenry\@mcs.anl.gov with jobid ".$jobid.", error message, and input file\n";	
			close(OUTPUT);
			exit(0);
		} else {
			if (!defined($results->{status}) || $results->{status} eq "failed") {
				open (OUTPUT, ">$outfile");
				print STDERR "Job failed on server with no error returned. Email chenry\@mcs.anl.gov with jobid ".$jobid.", and input file\n";
				print OUTPUT "Job failed on server with no error returned. Email chenry\@mcs.anl.gov with jobid ".$jobid.", and input file\n";	
				close(OUTPUT);
				exit(0);
			} elsif ($results->{status} eq "complete") {
				$continue = 0;
				$results = $results->{results};
			}
		}
	} else {
		open (OUTPUT, ">$outfile");
		print STDERR "Job failed on server with no results returned. Email chenry\@mcs.anl.gov with jobid ".$jobid." and input file\n";
		print OUTPUT "Job failed on server with no results returned. Email chenry\@mcs.anl.gov with jobid ".$jobid." and input file\n";	
		close(OUTPUT);
		exit(0);
	}
}
print "Results retreived! Printing results to file!\n";
#Printing results
my $headings = ["Labels","Descriptions","Media","Model","Genome","Fluxes","Biomass"];
my $translation = {Labels => "labels",Descriptions => "descriptions",Media => "media",Model => "model",Genome => "genome",Fluxes => "fluxes",Biomass => "biomass"};
open (OUTPUT, ">$outfile");
my $count = 1;
for (my $i=0; $i < @{$headings}; $i++) {
	if (defined($results->{$translation->{$headings->[$i]}})) {
		print OUTPUT $headings->[$i];
		if ($headings->[$i] eq "Fluxes") {
			for (my $j=0; $j < @{$results->{$translation->{$headings->[$i]}}}; $j++) {
				print OUTPUT "\t";
				foreach my $entity (keys(%{$results->{Fluxes}->[$j]})) {
					print OUTPUT $entity.":".$results->{fluxes}->[$j]->{$entity}.";";
				}
			}
		} else {
			for (my $j=0; $j < @{$results->{$translation->{$headings->[$i]}}}; $j++) {
				print OUTPUT "\t".$results->{$translation->{$headings->[$i]}}->[$j];
			}
		}
		print OUTPUT "\n";
	}
}
if (defined($results->{geneActivity})) {
	foreach my $gene (keys(%{$results->{geneActivity}})) {
		print OUTPUT $gene;
		for (my $j=0; $j < @{$results->{geneActivity}->{$gene}}; $j++) {
			print OUTPUT "\t".$results->{geneActivity}->{$gene}->[$j];
		}
		print OUTPUT "\n";
	}
}
close(OUTPUT);