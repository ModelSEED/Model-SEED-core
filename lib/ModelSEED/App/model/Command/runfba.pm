package ModelSEED::App::model::Command::runfba;
use base 'App::Cmd::Command';
use Class::Autouse qw(
    ModelSEED::Store
    ModelSEED::Auth::Factory
    ModelSEED::Reference
    ModelSEED::Configuration
    ModelSEED::App::Helpers
    ModelSEED::MS::Factories::ExchangeFormatFactory
);
sub abstract { return "Fill gaps in the reaction network for a model"; }
sub usage_desc { return "model runfba [ model || - ] [options]"; }
sub opt_spec {
    return (
        ["config|c:s", "Configuration filename for formulating the FBA"],
        ["overwrite|o", "Save FBA solution in existing model"],
        ["save|s:s", "Save FBA solution in a new model"],
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
        ["html","Print FBA results in HTML"],
    );
}

sub execute {
    my ($self, $opts, $args) = @_;
    my $auth  = ModelSEED::Auth::Factory->new->from_config;
    my $store = ModelSEED::Store->new(auth => $auth);
    my $helper = ModelSEED::App::Helpers->new();
    #Retreiving the model object on which FBA will be performed
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
	my $exchange_factory = ModelSEED::MS::Factories::ExchangeFormatFactory->new();
	my $fbaform = $exchange_factory->buildFBAFormulation($input);
    #Running FBA
    print STDERR "Running FBA..." if($opts->{verbose});
    my $fbaResult = $fbaform->runFBA();
    #Standard commands that save results of the analysis to the database
    if (!defined($fbaResult)) {
    	print STDERR " FBA failed with no solution returned!\n";
    } else {
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
	    if ($opts->{html}) {
	    	print $out_fh $fbaform->createHTML();
	    } else {
	    	print $out_fh $fbaform->toJSON({pp => 1});
	    }
    }
}

sub _getModel {
    my ($self, $args, $store) = @_;
    my $helper = ModelSEED::App::Helpers->new();
    $ref = $helper->get_base_ref("model", $args);
    if(defined($ref)) {
        return $store->get_object($ref);
    }
}

1;
