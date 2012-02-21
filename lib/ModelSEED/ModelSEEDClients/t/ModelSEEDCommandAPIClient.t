use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 5;
use lib "../../../myRAST/";
use lib "../";
use ModelSEEDCommandAPIClient;

my $msc = ModelSEEDCommandAPIClient->new();

#Testing each server function
{
    my $output = $msc->fbasimulatekomedialist({
    	model => "iBsu1103V2",
    	media => ["LB","NMS","GMM_nh4","GMM_gln"],
    	ko => [["peg.3"]]
    });
    print STDERR Data::Dumper->Dump([$output]);
    ok defined($output->{RESULTS}->{"peg.3"}), "Phenotype simulation failed!";
}