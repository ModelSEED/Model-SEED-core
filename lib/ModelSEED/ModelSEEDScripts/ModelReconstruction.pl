use strict;
use warnings;
use JSON::Any;
use ModelSEED::MS::Biochemistry;
use ModelSEED::MS::Mapping;
use ModelSEED::MS::Annotation;
use ModelSEED::MS::Model;
use ModelSEED::MS::Factories::SEEDFactory;
use Time::HiRes qw(time);
use Data::Dumper;

$| = 1;

#Loading biochemistry
my $directory = "C:/Code/Model-SEED-core/data/exampleObjects/";
open BIOCHEM, "<".$directory."biochemistry.json";
my $string = join("\n",<BIOCHEM>);
close BIOCHEM;
my $objectData = JSON::Any->decode($string);
my $biochem = ModelSEED::MS::Biochemistry->new($objectData);
#Loading mapping
open MAPPING, "<".$directory."mapping.json";
$string = join("\n",<MAPPING>);
close MAPPING;
$objectData = JSON::Any->decode($string);
my $mapping = ModelSEED::MS::Mapping->new($objectData);
$mapping->biochemistry($biochem);
#Retrieving annotation
#open ANNO, "<".$directory."FullAnnotation.json";
#$string = join("\n",<ANNO>);
#close ANNO;
#$objectData = JSON::Any->decode($string);
#my $anno = ModelSEED::MS::Annotation->new($objectData);
#$anno->mapping($mapping);
my $seedFactory = ModelSEED::MS::Factories::SEEDFactory->new();
my $anno = $seedFactory->buildMooseAnnotation({
	genome_id => "83333.1",
	mapping => $mapping
});
$anno->printJSONFile($directory."83333.1.json");
$mapping->printJSONFile($directory."83333.1.mapping.json");
my $readable = $anno->createReadableStringArray();
ModelSEED::utilities::PRINTFILE($directory."83333.1.readable",$readable);
##Building model
my $mdl = $anno->createStandardFBAModel();
my $data = $mdl->serializeToDB();
$mdl->printJSONFile($directory."ReconstructedModel.json");
$readable = $mdl->createReadableStringArray();
ModelSEED::utilities::PRINTFILE($directory."ReconstructedModel.readable",$readable);
