use strict;
use warnings;
use ModelSEED::FIGMODEL;
use ModelSEED::MS::Biochemistry;
use ModelSEED::MS::Mapping;
use ModelSEED::MS::Factories::PPOFactory;
use ModelSEEDbootstrap;

my $username = "public";
my $figmodel = ModelSEED::FIGMODEL->new({username => $username,password => "public"});
my $ppoFactory = ModelSEED::MS::Factories::PPOFactory->new({
	figmodel => $figmodel,
	namespace => $username
});

my $biochem = $ppoFactory->createBiochemistry();
$biochem->setParents(undef);
my $mapping = $ppoFactory->createMapping({
	biochemistry => $biochem
});
$mapping->setParents(undef);

print $figmodel->config("database root directory")->[0]."exampleObjects/biochemistry.json\n";
print $figmodel->config("database root directory")->[0]."exampleObjects/mapping.json\n";
$biochem->printJSONFile($figmodel->config("database root directory")->[0]."exampleObjects/biochemistry.json");
$mapping->printJSONFile($figmodel->config("database root directory")->[0]."exampleObjects/mapping.json");