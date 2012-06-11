use strict;
use warnings;
use JSON::Any;
use ModelSEED::MS::Biochemistry;
use ModelSEED::MS::Mapping;
use ModelSEED::MS::Annotation;
use ModelSEED::MS::Model;
use ModelSEED::MS::FBAFormulation;
use ModelSEED::MS::FBAProblem;
use Time::HiRes qw(time);

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
open MODEL, "<c:/Code/Model-SEED-core/data/exampleObjects/ReconstructedModel.json";
$string = join("",<MODEL>);
close MODEL;
$objectData = JSON::Any->decode($string);
my $model = ModelSEED::MS::Model->new($objectData);
$model->biochemistry($biochem);
my $mediaID = "ArgonneLBMedia";
my $media = $biochem->queryObject("media",{name => $mediaID});
if (!defined($media)) {
	print "Could not find specified media!";	
}
my $formulation = ModelSEED::MS::FBAFormulation->new({
	name => "Growth on Argonne LB",
	model_uuid => $model->uuid(),
	model => $model,
	media_uuid => $media->uuid(),
	media => $media,
	biochemistry_uuid => $biochem->uuid(),
	biochemistry => $biochem,
	type => "singlegrowth",
	maximizeObjective => 1,
	fbaObjectiveTerms => [{
			entityType => "Biomass",
			coefficient => 1,
			variableType => "biomassflux",
			variable_uuid => $model->biomasses()->[0]->uuid()
	}]
});
my $solution = $formulation->runFBA();
my $readable = $solution->createReadableStringArray();
ModelSEED::utilities::PRINTFILE("c:/Code/Model-SEED-core/data/exampleObjects/FBASolution.readable",$readable);