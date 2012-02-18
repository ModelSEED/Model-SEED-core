use strict;
use warnings;

use ModelSEED::CoreApi;
use ModelSEED::MS::Biochemistry;

use Time::HiRes qw(time);
use Data::Dumper;

my $bio_uuid = "DBB3B96A-3D63-11E1-94F6-C43F3D9902C7";

my $api = ModelSEED::CoreApi->new({
    database => "/home/paul/Documents/ModelSEEDCore/Model.db",
    driver   => "sqlite"
});

my $biochem = ModelSEED::MS::Biochemistry->new($bio_uuid, "master", $api);

print "Testing different methods to access reactions.\n";
print "First loading each individually...\n";

#my $rxn_ids = $biochem->getReactionIds();

#foreach my $rxn_id (@$rxn_ids) {
#    $biochem->getReaction($rxn_id, $bio_uuid);
#}

print "    just kidding, this takes forever to run (minutes).\n";
print "Using iterator which loads 100 at a time...\n";

my $time = time;
my $reaction_it = $biochem->getReactionIterator();
while ($reaction_it->hasNext) {
    $reaction_it->next();
}
print "    took " . sprintf("%.5f", time - $time) . " s\n";

print "Using CoreApi->getReactions which loads them all...\n";

$time = time;
my $rxns = $api->getReactions($bio_uuid);
print "    took " . sprintf("%.5f", time - $time) . " s\n";
