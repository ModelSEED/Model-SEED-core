use strict;
use warnings;
use ModelSEED::MS::Factories::SEEDFactory;
use ModelSEED::MS::Biochemistry;
use Test::More;

my $testCount = 0;
{
    my $om = ModelSEED::MS::ObjectManager->new();
    my $seedfact = ModelSEED::MS::Factories::SEEDFactory->new({om => $om});
    ok defined($om), "Created object manager!";
    ok defined($seedfact), "Created seedfactory!";
    my $anno = $seedfact->buildMooseAnnotation({
    	genome_id => "83333.1"
    });
    my $mapping = $anno->mapping();
    $anno->save();
    $mapping->save();
    ok defined($anno), "Created annotation!";
    $testCount += 2;
}
done_testing($testCount);