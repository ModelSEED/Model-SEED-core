use strict;
use warnings;
use ModelSEED::MS::Factories::SEEDFactory;
use ModelSEED::MS::Biochemistry;
use Test::More;
use Data::Dumper;

my $testCount = 0;
{
    # IMPORTANT - change hardcoded data directory in ObjectManager before running

    # my $om = ModelSEED::MS::ObjectManager->new();
    # $om->authenticate();
    # my $seedfact = ModelSEED::MS::Factories::SEEDFactory->new({om => $om});
    # ok defined($om), "Created object manager!";
    # ok defined($seedfact), "Created seedfactory!";
    # my $anno = $seedfact->buildMooseAnnotation({
    # 	genome_id => "83333.1"
    # });
    # my $mapping = $anno->mapping();
    # ok defined($anno), "Created annotation!";
    # ok defined($mapping), "Created mapping!";
    # print "Saving objects!";
    # $anno->save();
    # $mapping->save();

     print "Loading objects!\n";
     my $newom = ModelSEED::MS::ObjectManager->new();
     $newom->authenticate();
     my $newanno = $newom->get("Annotation",
         $newom->filedb->get_user_uuids("Annotation", $newom->user->{login})->[0]);
     my $newmapp = $newom->get("Mapping",
         $newom->filedb->get_user_uuids("Mapping", $newom->user->{login})->[0]);

     print STDERR Dumper([$newanno]); # OM returns raw data, not a moose object
     print STDERR Dumper([$newmapp]); # OM returns raw data, not a moose object

    $testCount += 4;
}
done_testing($testCount);
