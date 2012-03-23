use strict;
use warnings;
use ModelSEED::MS::Factories::SEEDFactory;
use ModelSEED::MS::Biochemistry;
use Test::More;

my $testCount = 0;
{
#    my $om = ModelSEED::MS::ObjectManager->new();
#    $om->authenticate();
#    my $seedfact = ModelSEED::MS::Factories::SEEDFactory->new({om => $om});
#    ok defined($om), "Created object manager!";
#    ok defined($seedfact), "Created seedfactory!";
#    my $anno = $seedfact->buildMooseAnnotation({
#    	genome_id => "83333.1"
#    });
#    my $mapping = $anno->mapping();
#    ok defined($anno), "Created annotation!";
#    print "Saving objects!";
#    $anno->save();
#    $mapping->save();
#    print "Loading objects!";
    my $newom = ModelSEED::MS::ObjectManager->new();
    $newom->authenticate();
    my $newanno = $newom->get("Annotation","EC5F1CDB-6DDD-1014-A066-EE3F867A2228");
    my $newmapp = $newom->get("Mapping","EC5C1CAD-6DDD-1014-80D8-E905E8051FE8");
    my $data = $newanno->serializeToDB();
    print STDERR Data::Dumper->Dump([$data]);
    $testCount += 2;
}
done_testing($testCount);