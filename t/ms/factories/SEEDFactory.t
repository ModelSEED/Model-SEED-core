use strict;
use warnings;
use ModelSEED::MS::Factories::SEEDFactory;
use Test::More;
use Data::Dumper;
my $testCount = 0;
{
     # Test basic object initialization
     my $factory = ModelSEED::MS::Factories::SEEDFactory->new;
     ok defined $factory, "Should create factory object";
     ok defined $factory->sapsvr, "Should create SAP server object";
     ok defined $factory->msseedsvr, "Should create MS Seed Support object";
     ok defined $factory->kbsvr, "Should create Kbase CDMI object";

    $testCount += 4;
}

# Tests for genome source
{
    my $factory = ModelSEED::MS::Factories::SEEDFactory->new;
    my %genomesToType = qw(
        83333.1 PUBSEED
        107806.10 PUBSEED
        224308.1 PUBSEED
        kb|g.0 KBase
    );
    foreach my $id (keys %genomesToType) {
        my $got = $factory->getGenomeSource($id);
        my $expected = $genomesToType{$id};
        is $got, $expected, "Should get correct type for $id";
        $testCount += 1;
    }
}

# Tests for listing genomes
{
    my $factory = ModelSEED::MS::Factories::SEEDFactory->new;
    my $kbGenomes = $factory->availableGenomes(source => 'KBASE');
    ok scalar(keys %$kbGenomes), "Got more than zero genomes from KBase";
    my $seedGenomes = $factory->availableGenomes(source => 'pubseed');
    ok scalar(keys %$seedGenomes), "Got more than zero genomes from PubSEED";
    # TODO - implement list for RAST
    $testCount += 2;
}

# TODO Tests for getting genome source

# Tests for getting genome attributes
{
    my $factory = ModelSEED::MS::Factories::SEEDFactory->new;
    my @genomes = qw(kb|g.0 83333.1 224308.1);
    foreach my $id (@genomes) {
        my $a = $factory->getGenomeAttributes($id);
        ok defined($a->{name}), "$id has name";
        ok defined($a->{taxonomy}), "$id has name";
        ok defined($a->{size}), "$id has size";
        ok defined($a->{gc}), "$id has gc";
        $testCount += 4;
    }
}

# TODO Tests for getting genome features
{
    my $factory = ModelSEED::MS::Factories::SEEDFactory->new;
    my @genomes = qw(kb|g.0);
    foreach my $id (@genomes) {
        my $a = $factory->getGenomeFeatures($id);
    }
}

done_testing($testCount);
