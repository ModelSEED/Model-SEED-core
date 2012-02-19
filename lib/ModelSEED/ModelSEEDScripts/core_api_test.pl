use strict;
use warnings;

use Data::Dumper;
use Time::HiRes qw(time);
use Devel::Size qw(total_size);

use JSON::XS;

use ModelSEED::CoreApi;

my $bio_uuid = "DBB3B96A-3D63-11E1-94F6-C43F3D9902C7";

my $api = ModelSEED::CoreApi->new({
    database => "/home/paul/Documents/ModelSEEDCore/Model.db",
    driver   => "sqlite"
});

# test reactions
my $time = time;
my $rxns = $api->getReactions($bio_uuid);
print "Got " . scalar @$rxns . " reactions in " . sprintf("%.3f", time - $time) . " seconds\n";

$time = time;
$rxns = $api->getReactions($bio_uuid, [['reactions.uuid', 'A21570E0-3D63-11E1-94F6-C43F3D9902C7']]);
print "Got " . scalar @$rxns . " reactions in " . sprintf("%.3f", time - $time) . " seconds\n";

$time = time;
my $rxn = $api->getReaction("A21570E0-3D63-11E1-94F6-C43F3D9902C7", $bio_uuid);
print "Got reaction in " . sprintf("%.3f", time - $time) . " seconds\n";

$time = time;
$rxns = $api->getReactions($bio_uuid, [['deltaG', '<', '10000000']]);
print "Got " . scalar @$rxns . " reactions in " . sprintf("%.3f", time - $time) . " seconds\n";

# test compounds
$time = time;
my $cpds = $api->getCompounds($bio_uuid);
print "Got " . scalar @$cpds . " compounds in " . sprintf("%.3f", time - $time) . " seconds\n";

$time = time;
my $cpd = $api->getCompound("641122EE-3D63-11E1-94F6-C43F3D9902C7", $bio_uuid);
print "Got compound in " . sprintf("%.3f", time - $time) . " seconds\n";

# test biochemistry
$time = time;
my $biochem = $api->getBiochemistry($bio_uuid, "master");
print "Got biochemistry in " . sprintf("%.3f", time - $time) . " seconds\n";
print total_size($biochem) . " bytes\n";

# test biochemistry
$time = time;
$biochem = $api->getBiochemistrySimple($bio_uuid, "master");
print "Got simple biochemistry in " . sprintf("%.3f", time - $time) . " seconds\n";
print total_size($biochem) . " bytes\n";

exit;
