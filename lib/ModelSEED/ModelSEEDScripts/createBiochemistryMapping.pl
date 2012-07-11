use strict;
use warnings;
use ModelSEED::FIGMODEL;
use ModelSEED::MS::Biochemistry;
use ModelSEED::MS::Mapping;
use ModelSEED::MS::Factories::PPOFactory;
use ModelSEEDbootstrap;

my $figmodel = ModelSEED::FIGMODEL->new({username => "public",password => "public"});
my $ppoFactory = ModelSEED::MS::Factories::PPOFactory->new({
	figmodel => $figmodel,
	namespace => "public"
});

my $biochem = $ppoFactory->createBiochemistry();
my $mapping = $ppoFactory->createMapping({
	biochemistry => $biochem
});

$biochem->printJSONFile($figmodel->config("database root directory")->[0]."exampleObjects/biochemistry.json");
$mapping->printJSONFile($figmodel->config("database root directory")->[0]."exampleObjects/mapping.json");
my $readable = $biochem->createReadableStringArray();
ModelSEED::utilities::PRINTFILE($figmodel->config("database root directory")->[0]."exampleObjects/Biochemistry.readable",$readable);
$readable = $mapping->createReadableStringArray();
ModelSEED::utilities::PRINTFILE($figmodel->config("database root directory")->[0]."exampleObjects/Mapping.readable",$readable);