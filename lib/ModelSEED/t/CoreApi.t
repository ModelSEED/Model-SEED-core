use strict;
use warnings;
use Test::More;
use ModelSEED::TestingHelpers;

my $testCount = 0;
my $helper = ModelSEED::TestingHelpers->new();
my $api = $helper->getDebugCoreApi();
$api->_initOM();
{
    ok defined $api->{om}, "Should have OM after call to _initOM";
    $testCount += 1;
}

done_testing($testCount);
