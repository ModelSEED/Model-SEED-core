use strict;
use warnings;
use JSON::Any;
use ModelSEED::MS::ObjectManager;
use Time::HiRes qw(time);

open FILE, "<c:/Code/Model-SEED-core/data/exampleObjects/FullBiochemistry.json";
my $time = time;
my $string = <FILE>;
my $objectData = JSON::Any->decode($string);
print "File load done!";
my $biochem = ModelSEED::MS::Biochemistry->new($objectData);
my $length = length($string);

#my @string = <FILE>;
#my $length = 0;
#map {$length += length($_)} @string;

$time = (time - $time);
$time = sprintf("%.3f", $time);
print "Read $length chars in $time seconds\n";
