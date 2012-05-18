use strict;
use warnings;
use JSON::Any;
use ModelSEED::MS::Factories::SEEDFactory;
use Time::HiRes qw(time);

my $mediaID = "ArgonneLBMedia";

open BIOCHEM, "<c:/Code/Model-SEED-core/data/exampleObjects/FullBiochemistry.json";
my $string = <BIOCHEM>;
my $objectData = JSON::Any->decode($string);
my $biochem = ModelSEED::MS::Biochemistry->new($objectData);
close BIOCHEM;
print "Loaded biochemistry!\n";

open MODEL, "<c:/Code/Model-SEED-core/data/exampleObjects/FullModel.json";
$string = <MODEL>;
$objectData = JSON::Any->decode($string);
my $mdl = ModelSEED::MS::Model->new($objectData);
close MODEL;
print "Loaded model!\n";

my $media = $biochem->get_object("Media",{name => $mediaID});
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

$mdl->runFBA($formulation);