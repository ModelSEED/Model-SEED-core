use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 5;
use MSSeedSupportClient;

my $mss = MSSeedSupportClient->new();

#Testing each server function
{
    my $usrdata = $mss->get_user_info({
    	username => "reviewer",
    	password => "reviewer",
    });
    ok defined($usrdata->{username}), "User account not found or authentication failed!";
    $usrdata = $mss->blast_sequence({
    	sequences => ["atgaaacgcattagcaccaccattaccaccaccatcaccattaccacagg"],
    	genomes => ["83333.1"]
    });
    ok defined($usrdata->{"atgaaacgcattagcaccaccattaccaccaccatcaccattaccacagg"}), "Expected sequence not found!";
    $usrdata = $mss->pegs_of_function({
    	roles => ["Thr operon leader peptide"]
    });
    ok defined($usrdata->{"Thr operon leader peptide"}), "Expected role not found!";
    $usrdata = $mss->getRastGenomeData({
    	genome => "315750.3",
    	username => "reviewer",
    	password => "reviewer"
    });
    ok defined(@{$usrdata->{features}} > 1000), "Genome not retrieved!";
    $usrdata = $mss->users_for_genome({
    	genome => "315750.3",
    	username => "reviewer",
    	password => "reviewer"
    });
    ok defined($usrdata->{"315750.3"}->{"chenry"}), "Users for genome not retrieved!";
}
