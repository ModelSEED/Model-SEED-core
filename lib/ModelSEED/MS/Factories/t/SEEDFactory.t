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
    my $anno = $seedfact->buildMooseAnnotation({
    	genome_id => "83333.1"
    });
    ok defined($anno), "Created annotation!";
    my $data = $anno->serializeToDB();
    print STDERR Data::Dumper->Dump([$data]);
    #$data = $anno->mapping()->serializeToDB();
    #print STDERR Data::Dumper->Dump([$data]);
    $testCount += 2;
}
done_testing($testCount);