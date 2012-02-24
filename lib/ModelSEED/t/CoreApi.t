use strict;
use warnings;
use Test::More;
use lib "../DB";
use ModelSEED::TestingHelpers;
use ModelSEED::MS::Biochemistry;

my $testCount = 0;
my $helper = ModelSEED::TestingHelpers->new();
my $api = $helper->getDebugCoreApi();
$api->_initOM();
{
    ok defined $api->{om}, "Should have OM after call to _initOM";
    $testCount += 1;
    my $data = $api->getBiochemistry({
    	uuid => "358CFC9A-5E60-11E1-9EC2-C7374BC191FA",
		with_all => 1,
		user => "master"
    });
    #print STDERR Data::Dumper->Dump([$data]);
    my $biochem = ModelSEED::MS::Biochemistry->new($data);
}

done_testing($testCount);
