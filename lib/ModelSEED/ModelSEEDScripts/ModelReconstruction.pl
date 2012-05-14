use strict;
use warnings;
use JSON::Any;
use ModelSEED::MS::Factories::SEEDFactory;
use Time::HiRes qw(time);

open BIOCHEM, "<c:/Code/Model-SEED-core/data/exampleObjects/FullBiochemistry.json";
my $string = <BIOCHEM>;
my $objectData = JSON::Any->decode($string);
my $biochem = ModelSEED::MS::Biochemistry->new($objectData);
close BIOCHEM;

open MAPPING, "<c:/Code/Model-SEED-core/data/exampleObjects/FullMapping.json";
$string = <MAPPING>;
$objectData = JSON::Any->decode($string);
my $mapping = ModelSEED::MS::Mapping->new($objectData);
close MAPPING;

my $seedFactory = ModelSEED::MS::SEEDFactory->new();
my $anno = $seedFactory->buildMooseAnnotation({
	genome_id => "83333.1",
	mapping => $mapping
});

my $mdl = $anno->createStandardFBAModel();
$mdl->printJSONFile("c:/Code/Model-SEED-core/data/exampleObjects/ReconstructedModel.json");