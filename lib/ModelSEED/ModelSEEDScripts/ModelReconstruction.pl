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

#open MAPPING, "<c:/Code/Model-SEED-core/data/exampleObjects/FullMapping.json";
#my $string = <MAPPING>;
#close MAPPING;
#my $gzipString;
#gzip \$string => \$gzipString;
#open DATA, ">c:/Code/Model-SEED-core/data/exampleObjects/FullMapping.json.zip";
#print DATA $gzipString;
#close DATA;

my $string;
my $gzipString;
open DATATWO, "<c:/Code/Model-SEED-core/data/exampleObjects/FullBiochemistry.json.zip";
read DATATWO,$gzipString,10000000;
close DATATWO;
gunzip \$gzipString => \$string;
my $objectData = JSON::Any->decode($string);
my $biochem = ModelSEED::MS::Biochemistry->new($objectData);
exit();

#open BIOCHEM, "<c:/Code/Model-SEED-core/data/exampleObjects/FullBiochemistry.json";
#$string = <BIOCHEM>;
#close BIOCHEM;
#
#gzip \$string => \$gzipString;
#my $length = length($gzipString);
#open DATA, ">c:/Code/Model-SEED-core/data/exampleObjects/FullBiochemistry.json.zip";
#print DATA $gzipString;
#close DATA;


#$gzipString = <DATATWO>;




my $readable = $biochem->createReadableStringArray();
ModelSEED::utilities::PRINTFILE("c:/Code/Model-SEED-core/data/exampleObjects/FullBiochemistry.readable",$readable); 
print "Loaded biochemistry!\n";
open MODEL, "<c:/Code/Model-SEED-core/data/exampleObjects/FullModel.json";
$string = <MODEL>;
$objectData = JSON::Any->decode($string);
my $mdl = ModelSEED::MS::Model->new($objectData);
close MODEL;
$mdl->biochemistry($biochem);
$readable = $mdl->createReadableStringArray();
ModelSEED::utilities::PRINTFILE("c:/Code/Model-SEED-core/data/exampleObjects/FullModel.readable",$readable); 
exit();
open MAPPING, "<c:/Code/Model-SEED-core/data/exampleObjects/FullMapping.json";
$string = <MAPPING>;
$objectData = JSON::Any->decode($string);
my $mapping = ModelSEED::MS::Mapping->new($objectData);
close MAPPING;
$mapping->biochemistry($biochem);
print "Loaded mapping!\n";
my $seedFactory = ModelSEED::MS::Factories::SEEDFactory->new();
my $anno = $seedFactory->buildMooseAnnotation({
	genome_id => "83333.1",
	mapping => $mapping
});
print "Created annotation!\n";
$mdl = $anno->createStandardFBAModel();
$mdl->printJSONFile("c:/Code/Model-SEED-core/data/exampleObjects/ReconstructedModel.json");