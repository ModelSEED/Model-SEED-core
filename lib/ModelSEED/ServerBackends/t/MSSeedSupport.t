use strict;
use warnings;
use lib "/home/chenry/Model-SEED-core/config/";
use ModelSEEDbootstrap;
use Test::More tests => 7;
use Data::Dumper;
use MSSeedSupport;

my $mss = MSSeedSupport->new();

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
    	genome => "315750.3",
    	username => "reviewer",
    	password => "reviewer"
    });
    ok defined($usrdata->{features}->size() > 1000), "Genome not retrieved!";
    $usrdata = $mss->genomeType({
    	ids => ["315750.3"],
    	username => "reviewer",
    	password => "reviewer"
    });
    ok defined($usrdata->{"315750.3"}->{source}), "Genome not retrieved!";
    $usrdata = $mss->genomeData({
    	ids => ["315750.3"],
    	username => "reviewer",
    	password => "reviewer"
    });
    ok defined($usrdata->{"315750.3"}->{features}) && @{$usrdata->{"315750.3"}->{features}} > 1000, "Genome not retrieved!";
    #print STDERR Data::Dumper->Dump([$usrdata]);
    $usrdata = $mss->users_for_genome({
    	genome => "315750.3",
    	username => "reviewer",
    	password => "reviewer"
    });
    ok defined($usrdata->{"315750.3"}->{"chenry"}), "Users for genome not retrieved!";
}
