use strict;
use warnings;
use ModelSEED::generatePriceData;
use Test::More;
my $testCount = 0;

my $pd = ModelSEED::generatePriceData->new({
  likelihood   => 'likelihood',
  input      => 'input',
  model      => 'Seed83333.1',
  biomass    => ['bio00179'],
  media      => ['ArgonneLBMedia'],
  DBdsn      => 'dbi:mysql:RoseDB:bio-app-authdb.mcs.anl.gov',
  DBusername => 'webappuser',
});

# Basic tests
{
    ok defined($pd), "Should create class object";
    ok defined($pd->coreApi), "Core api should initialize correctly";
    ok defined($pd->modelObject), "Should get modelObject";
    ok defined($pd->bioObject), "Should get biomass object";
    $testCount += 4;
}

# Testing conversion of compounds
{
    my $cpd0 = $pd->bioObject->compounds->[0];
    my $cpd1 =  $pd->bioObject->compounds->[1];
    is 0, $pd->convertCompound($cpd0), "First compound should be with id 0";
    is 1, $pd->convertCompound($cpd1), "Second compound should have id 1";
    is 0, $pd->convertCompound($cpd0), "Seeing first compound again should get 0";
    is 1, $pd->convertCompound($cpd1), "Seeing second compound again should get 1";
    # internal tests
    ok defined($pd->conversionIndexes->{compound}), "Compound has indexes";
    ok defined($pd->conversionData->{compound}), "Compound has data";
    is 2, scalar(keys %{$pd->conversionData->{compound}}), "Should be two entries in data";

    $testCount += 7;
}

# Testing createMediaNameNode
{
    my $node = $pd->createMediaNameNode("foo");
    ok $node->toString eq "<mediaName>foo</mediaName>", "";
    $testCount += 1;
}



done_testing($testCount);

