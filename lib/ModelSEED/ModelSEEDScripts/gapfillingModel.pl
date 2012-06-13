use strict;
use warnings;
use JSON::Any;
use ModelSEED::MS::Factories::ExchangeFormatFactory;
use ModelSEED::MS::ModelAnalysis;
use ModelSEED::MS::GapfillingFormulation;
use ModelSEED::MS::FBAFormulation;
use ModelSEED::MS::FBAProblem;
use ModelSEED::MS::Biochemistry;
use ModelSEED::MS::Annotation;
use ModelSEED::MS::Model;
use ModelSEED::MS::Mapping;

$ENV{MODEL_SEED_CORE} = "c:/Code/Model-SEED-core/";
$ENV{GLPK} = "\"C:/Program Files/GnuWin32/bin/glpsol.exe\"";
$ENV{CPLEX} = "C:/ILOG/CPLEX_Studio_AcademicResearch122/cplex/bin/x86_win32/cplex.exe";

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
open ANNO, "<c:/Code/Model-SEED-core/data/exampleObjects/83333.1.json";
$string = join("",<ANNO>);
close ANNO;
$objectData = JSON::Any->decode($string);
my $anno = ModelSEED::MS::Annotation->new($objectData);
$mapping->biochemistry($biochem);
open GAPFORM, "<c:/Code/Model-SEED-core/data/exampleObjects/GapfillingFormulation.exchange";
my $filedata = [<GAPFORM>];
close GAPFORM;
my $exFact = ModelSEED::MS::Factories::ExchangeFormatFactory->new();
for (my $i=0; $i < @{$filedata}; $i++) {
	chomp($filedata->[$i]);
}
my $gapform = $exFact->buildObjectFromExchangeFileArray({
	array => $filedata,
	Biochemistry => $biochem,
});
print "Loaded!";
$gapform->biochemistry($biochem);
$gapform->media($biochem->getObject("media",$gapform->media_uuid()));
open MODEL, "<c:/Code/Model-SEED-core/data/exampleObjects/ReconstructedModel.json";
$string = join("",<MODEL>);
close MODEL;
$objectData = JSON::Any->decode($string);
my $model = ModelSEED::MS::Model->new($objectData);
$model->biochemistry($biochem);
$model->annotation($anno);
my $mdlanal = ModelSEED::MS::ModelAnalysis->new();
$model->modelanalysis_uuid($mdlanal->uuid());
$model->modelanalysis($mdlanal);

my $fbaform = ModelSEED::MS::FBAFormulation->new({
	name => "Growth test",
	model_uuid => $model->uuid(),
	model => $model,
	media_uuid => $gapform->media_uuid(),
	media => $gapform->media(),
	type => "singlegrowth",
	biochemistry_uuid => $biochem->uuid(),
	biochemistry => $biochem,
	description => "Growth test",
	growthConstraint => "none",
	thermodynamicConstraints => "none",
	allReversible => 0,
	defaultMaxFlux => 1000,
	defaultMaxDrainFlux => 0,
	defaultMinDrainFlux => -10000,
	decomposeReversibleFlux => 0,
	decomposeReversibleDrainFlux => 0,
	fluxUseVariables => 0,
	drainfluxUseVariables => 0,
	maximizeObjective => 1,
	fbaObjectiveTerms => [{
		coefficient => 1,
		entityType => "Biomass",
		variableType => "biomassflux",
		entity_uuid => $model->biomasses()->[0]->uuid()
	}]			
});
my $fbasolution = $fbaform->runFBA();
$fbasolution->createHTML();
my $readable = $fbasolution->createHTML();
ModelSEED::utilities::PRINTFILE($directory."FBASolution.html",[$readable]);

$model->gapfillModel({
	gapfillingFormulation => $gapform
});
$model->printJSONFile($directory."GapfilledModel.json");
$readable = $model->createHTML();
ModelSEED::utilities::PRINTFILE($directory."GapfilledModel.html",[$readable]);
