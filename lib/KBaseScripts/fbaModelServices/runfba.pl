########################################################################
# runfba.pl - This is a KBase command script automatically built from server specifications
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use lib "/home/chenry/kbase/models_api/clients/";
use fbaModelServicesClient;
use JSON::XS;
use Getopt::Long;

my $obj = command->new();
my $opts = KBase::Client::utilities::runcommand->($obj->opt_spec());

$obj->execute($opts, $args,"fbaModelServicesClient","http://bio-data-1.mcs.anl.gov/services/fba");

	
my $optionSpecs = $self->opt_spec();
my $clientObj = $service->new($url);





sub runcommand {
	my ($self, $opts, $args,$service,$url) = @_;
	my $optArray;
	my $output;
	for (my $i=0; $i < @{$opts}; $i++) {
		push(@{$optArray},$opts->[$i]->[0]);
		push(@{$optArray},\($output->{$i}));
	}
	$output = GetOptions(@{$optArray});
	
	
	
	
	return $output;
}

my $input_file;
my $output_file;
my $sinput;
my $url = ;



my $usage = "runfba [--input model-file] [--output model-file] [--form formulation] [--url service-url] [< model-file] [> model-file]";

@ARGV == 0 or die "Usage: $usage\n";



my $in_fh;
if ($input_file)
{
    open($in_fh, "<", $input_file) or die "Cannot open $input_file: $!";
}
else
{
    $in_fh = \*STDIN;
}

my $out_fh;
if ($output_file)
{
    open($out_fh, ">", $output_file) or die "Cannot open $output_file: $!";
}
else
{
    $out_fh = \*STDOUT;
}
my $json = JSON::XS->new;

my $input;
{
    local $/;
    undef $/;
    my $input_txt = <$in_fh>;
    $input = $json->decode($input_txt)
}

my $formulation;
if (-e $sinput) {
	my $in_sfh;
	open($in_sfh, "<", $sinput) or die "Cannot open $sinput: $!";
	$formulation = join("",@{<$in_sfh>});
	close($in_sfh);
} else {
	$formulation = $sinput;
}
my $output = $fbaModelServicesObj->runfba($input,$formulation);

$json->pretty(1);
print $out_fh $json->encode($output);
close($out_fh);


package command;

sub abstract { return "Fill gaps in the reaction network for a model"; }
sub usage_desc { return "model runfba [ model || - ] [options]"; }
sub opt_spec {
    return (
        ["config|c:s", "Configuration filename for formulating the gapfilling"],
        ["overwrite|o", "Overwrite existing model with gapfilled model"],
        ["save|s:s", "Save gapfilled model to new model name"],
        ["verbose|v", "Print verbose status information"],
        ["fileout|f:s", "Name of file where FBA solution object will be printed"],
        ["media:s","Media formulation to be used for the FBA simulation"],
        ["notes:s","User notes to be affiliated with FBA simulation"],
        ["objective:s","String describing the objective of the FBA problem"],
        ["objfraction:s","Fraction of the objective to enforce to ensure"],
        ["rxnko:s","Comma delimited list of reactions to be knocked out"],
        ["geneko:s","Comma delimited list of genes to be knocked out"],
        ["uptakelim:s","List of max uptakes for atoms to be used as constraints"],
        ["defaultmaxflux:s","Maximum flux to use as default"],
        ["defaultmaxuptake:s","Maximum uptake flux to use as default"],
        ["defaultminuptake:s","Minimum uptake flux to use as default"],
        ["fva","Perform flux variability analysis"],
        ["simulateko","Simulate single gene knockouts"],
        ["minimizeflux","Minimize fluxes in output solution"],
        ["findminmedia","Predict minimal media formulations for the model"],
        ["allreversible","Make all reactions reversible in FBA simulation"],
        ["simplethermoconst","Use simple thermodynamic constraints"],
        ["thermoconst","Use standard thermodynamic constraints"],
        ["nothermoerror","Do not include uncertainty in thermodynamic constraints"],
        ["minthermoerror","Minimize uncertainty in thermodynamic constraints"],
    );
}

sub execute {
	my ($self, $opts, $args,$service,$url) = @_;
	
	
    
    
    my $overrideList = {
		media => "media",notes => "notes",fva => "fva",simulateko => "comboDeletions",
		minimizeflux => "fluxMinimization",findminmedia => "findMinimalMedia",objfraction => "objectiveConstraintFraction",
		allreversible => "allReversible",objective => "objectiveString",rxnko => "geneKO",geneko => "reactionKO",uptakelim => "uptakeLimits",
		defaultmaxflux => "defaultMaxFlux",defaultminuptake => "defaultMinDrainFlux",defaultmaxuptake => "defaultMaxDrainFlux",
		simplethermoconst => "simpleThermoConstraints",thermoconst => "thermodynamicConstraints",nothermoerror => "noErrorThermodynamicConstraints",
		minthermoerror => "minimizeErrorThermodynamicConstraints"
	};
	foreach my $argument (keys(%{$overrideList})) {
		if (defined($opts->{$argument})) {
			$input->{overrides}->{$overrideList->{$argument}} = $opts->{$argument};
		}
	}
    
    
    
    
    
    
    
    
    (my $model,my $ref) = $helper->get_object("model",$args,$store);
    $self->usage_error("Model not found; You must supply a valid model name.") unless(defined($model));
	#Standard commands to handle where output will be printed
    my $out_fh;
	if ($opts->{fileout}) {
	    open($out_fh, ">", $opts->{fileout}) or die "Cannot open ".$opts->{fileout}.": $!";
	} else {
	    $out_fh = \*STDOUT;
	}
	#Creating FBA formulation
	my $input = {model => $model};
	if ($opts->{config}) {
		$input->{filename} = $opts->{config};
	}
	
	my $exchange_factory = ModelSEED::MS::Factories::ExchangeFormatFactory->new();
	my $fbaform = $exchange_factory->buildFBAFormulation($input);
    #Running FBA
    print STDERR "Running FBA..." if($opts->{verbose});
    my $fbaResult = $fbaform->runFBA();
    #Standard commands that save results of the analysis to the database
    if (!defined($fbaResult)) {
    	print STDERR " FBA failed with no solution returned!\n";
    } else {
		print $out_fh $fbaform->toJSON({pp => 1});
	    #Standard commands that save results of the analysis to the database
	    if ($opts->{overwrite}) {
	    	print STDERR "Saving model with FBA solution over original model...\n" if($opts->{verbose});
	    	$model->add("fbaFormulations",$fbaform);
	    	$store->save_object($ref,$model);
	    } elsif ($opts->{save}) {
			$ref = $helper->process_ref_string($opts->{save}, "model", $auth->username);
			print STDERR "Saving model with FBA solution as new model ".$ref."...\n" if($opts->{verbose});
			$model->add("fbaFormulations",$fbaform);
			$store->save_object($ref,$model);
	    }
    }
}
