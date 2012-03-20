use strict;
use warnings;
use ModelSEED::MS::Factories::SEEDFactory;
use Test::More;

my $testCount = 0;
{
    my $om = ModelSEED::MS::ObjectManager->new();
    my $seedfact = ModelSEED::MS::Factories::SEEDFactory->new({om => $om});
    ok defined($om), "Created object manager!";
    ok defined($seedfact), "Created seedfactory!";
    $testCount += 2;
}
done_testing($testCount);