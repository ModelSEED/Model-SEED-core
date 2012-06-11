use strict;
use warnings;
use JSON::Any;
use ModelSEED::MS::Factories::ExchangeFormatFactory;
use ModelSEED::MS::ModelAnalysis;
use ModelSEED::MS::GapfillingFormulation;
use ModelSEED::MS::FBAFormulation;
use ModelSEED::MS::FBAProblem;
use ModelSEED::MS::Biochemistry;
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
$model->gapfillModel({
	gapfillingFormulation => $gapform
});

