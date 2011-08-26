
use strict;
use FBAMODELserver;
use ClientThing;

my $ServerObject = FBAMODELserver->new();

#1.) Getting the complete list of available media conditions
my $model = "Seed83333.1";
my $media = $ServerObject->get_media_id_list();

#2.) Running FBA on all media contiions
my $FBAInput;
for (my $i=0; $i < 1; $i++) {
	push(@{$FBAInput->{parameters}},{id => $model,media => "Carbon-D-Glucose",reactionKO => ["none"],geneKO => ["none"],user => "PUBLIC",password => ""});
}
my $output = $ServerObject->simulate_model_growth($FBAInput);

#3.) Printing results to file
open (OUTPUT, ">FBAResults.txt");
print OUTPUT "Media ID\tGrowth\n";
for (my $i=0; $i < @{$output}; $i++) {
	print OUTPUT $output->[$i]->{media}."\t".$output->[$i]->{growth}."\n";
}
close(OUTPUT);

#4.) Simulating single gene knockouts on some different media conditions
$FBAInput = {};
for (my $i=0; $i < 1; $i++) {
	push(@{$FBAInput->{parameters}},{id => $model,media => "Carbon-D-Glucose",reactionKO => ["none"],geneKO => ["none"],user => "PUBLIC",password => ""});
}
$output = $ServerObject->simulate_all_single_gene_knockout($FBAInput);

#3.) Printing results to file
open (OUTPUT, ">KOResults.txt");
print OUTPUT "Media ID\tEssential genes\n";
for (my $i=0; $i < @{$output}; $i++) {
	print OUTPUT $output->[$i]->{media}."\t".join(",",@{$output->[$i]->{"essential genes"}})."\n";
}
close(OUTPUT);