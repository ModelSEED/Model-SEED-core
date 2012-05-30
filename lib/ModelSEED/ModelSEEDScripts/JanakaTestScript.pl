use strict;
use warnings;
use JSON::Any;
use ModelSEED::MS::Biochemistry;
use ModelSEED::MS::Mapping;
use ModelSEED::MS::Annotation;
use ModelSEED::MS::Model;
use ModelSEED::MS::Factories::SEEDFactory;
use Time::HiRes qw(time);
use IO::Compress::Gzip qw(gzip);
use IO::Uncompress::Gunzip qw(gunzip);

#Loading biochemistry
my $string;
my $gzipString;
open BIOCHEM, "<c:/Code/Model-SEED-core/data/exampleObjects/FullBiochemistry.json.zip";
read BIOCHEM,$gzipString,10000000;
close BIOCHEM;
gunzip \$gzipString => \$string;
my $objectData = JSON::Any->decode($string);
my $biochem = ModelSEED::MS::Biochemistry->new($objectData);
$biochem->setParents(undef);
print "Biochemistry loaded!\n";
#Loading mapping
open MAPPING, "<c:/Code/Model-SEED-core/data/exampleObjects/FullMapping.json.zip";
read MAPPING,$gzipString,10000000;
close MAPPING;
gunzip \$gzipString => \$string;
$objectData = JSON::Any->decode($string);
my $mapping = ModelSEED::MS::Mapping->new($objectData);
$mapping->setParents(undef);
$mapping->biochemistry($biochem);
print "Mapping loaded!\n";
$mapping->buildSubsystemReactionSets();