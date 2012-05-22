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
use IO::Compress::Gzip qw(gzip);
use IO::Uncompress::Gunzip qw(gunzip);

$ENV{MODEL_SEED_CORE} = "c:/Code/Model-SEED-core/";
$ENV{GLPK} = "\"C:/Program Files/GnuWin32/bin/glpsol.exe\"";
$ENV{CPLEX} = "C:/ILOG/CPLEX_Studio_AcademicResearch122/cplex/bin/x86_win32/cplex.exe";

my $mediaID = "ArgonneLBMedia";
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

open MODEL, "<c:/Code/Model-SEED-core/data/exampleObjects/ReconstructedModel.json";
$string = <MODEL>;
$objectData = JSON::Any->decode($string);
my $mdl = ModelSEED::MS::Model->new($objectData);
$mdl->biochemistry($biochem);
$mdl->setParents(undef);
close MODEL;
print "Loaded model!\n";

my $media = $biochem->getObject("Media",{name => $mediaID});
if (!defined($media)) {
	print "Could not find specified media!";	
}

my $formulation = ModelSEED::MS::FBAFormulation->new({
	name => "Growth on Argonne LB",
	model_uuid => $mdl->uuid(),
	model => $mdl,
	media_uuid => $media->uuid(),
	media => $media,
	biochemistry_uuid => $biochem->uuid(),
	biochemistry => $biochem,
	type => "singlegrowth",
	maximizeObjective => 1,
	fbaObjectiveTerms => [{
			coefficient => 1,
			variableType => "biomassflux",
			variable_uuid => $mdl->biomasses()->[0]->uuid()
	}]
});
my $solution = $formulation->runFBA();
my $readable = $solution->createReadableStringArray();
ModelSEED::utilities::PRINTFILE("c:/Code/Model-SEED-core/data/exampleObjects/FBASolution.readable",$readable);