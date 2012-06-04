use strict;
use warnings;
use JSON::Any;
use ModelSEED::MS::Factories::ExchangeFormatFactory;
use ModelSEED::MS::GapfillingFormulation;
use ModelSEED::MS::FBAFormulation;
use ModelSEED::MS::FBAProblem;
use ModelSEED::MS::Biochemistry;
use ModelSEED::MS::Model;
use Time::HiRes qw(time);
use Data::Dumper;
use IO::Compress::Gzip qw(gzip);
use IO::Uncompress::Gunzip qw(gunzip);

$ENV{MODEL_SEED_CORE} = "c:/Code/Model-SEED-core/";
$ENV{GLPK} = "\"C:/Program Files/GnuWin32/bin/glpsol.exe\"";
$ENV{CPLEX} = "C:/ILOG/CPLEX_Studio_AcademicResearch122/cplex/bin/x86_win32/cplex.exe";

my $string;
open BIOCHEM, "<c:/Code/Model-SEED-core/data/exampleObjects/FullBiochemistry.json";
$string = join("",<BIOCHEM>);
close BIOCHEM;
my $objectData = JSON::Any->decode($string);
my $biochem = ModelSEED::MS::Biochemistry->new($objectData);
$biochem->setParents(undef);
print "Biochemistry loaded!\n";

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
$gapform->biochemistry($biochem);
$gapform->media($biochem->queryObject("media",[$gapform->media_uuid()]));

open MODEL, "<c:/Code/Model-SEED-core/data/exampleObjects/ReconstructedModel.json";
$string = join("",<MODEL>);
close MODEL;
$objectData = JSON::Any->decode($string);
my $model = ModelSEED::MS::Model->new($objectData);
$model->biochemistry($biochem);
$model->setParents(undef);
$model->gapfillModel({
	gapfillingFormulation => $gapform
});

