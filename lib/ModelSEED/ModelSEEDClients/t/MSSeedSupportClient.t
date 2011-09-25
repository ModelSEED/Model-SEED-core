use strict;
use warnings;
use Test::More qw(no_plan);
use Data::Dumper;
use MSSeedSupportClient;

my $mss = MSSeedSupportClient->new();

#Testing each server function
{
    my $usrdata = $mss->get_user_info({
    	username => "reviewer",
    	password => "reviewer"
    });
    #print STDERR Data::Dumper->Dump([$usrdata]);
    ok defined($usrdata->{username}), "User account not found or authentication failed!";
    $usrdata = $mss->blast_sequence({
    	sequences => ["atgaaacgcattagcaccaccattaccaccaccatcaccattaccacagg"],
    	genomes => ["83333.1"]
    });
    #print STDERR Data::Dumper->Dump([$usrdata]);
    ok defined($usrdata->{"atgaaacgcattagcaccaccattaccaccaccatcaccattaccacagg"}), "Expected sequence not found!";
    $usrdata = $mss->pegs_of_function({
    	roles => ["Thr operon leader peptide"]
    });
    #print STDERR Data::Dumper->Dump([$usrdata]);
    ok defined($usrdata->{"Thr operon leader peptide"}), "Expected role not found!";
    $usrdata = $mss->getRastGenomeData({
    	genome => "573064.5",
    	username => "chenry",
    	password => "hello824"
    });
    ok defined($usrdata->{features}->size() > 1000), "Genome not retrieved!";
    $usrdata = $mss->users_for_genome({
    	genome => "573064.5",
    	username => "chenry",
    	password => "hello824"
    });
    #print STDERR Data::Dumper->Dump([$usrdata]);
    ok defined($usrdata->{"573064.5"}->{"chenry"}), "Users for genome not retrieved!";
}
