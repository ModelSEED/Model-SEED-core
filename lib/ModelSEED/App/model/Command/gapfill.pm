package ModelSEED::App::model::Command::gapfill;
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
sub usage_desc { return "model gapfill [ model || - ] [options]"; }
sub opt_spec {
    return (
        ["config|c=s", "Configuration filename for formulating the gapfilling"],
        ["overwrite|o", "Overwrite existing model with gapfilled model"],
        ["save|s:s", "Save gapfilled model to new model name"],
        ["verbose|v", "Print verbose status information"],
    );
}

sub execute {
    my ($self, $opts, $args) = @_;
    my $auth  = ModelSEED::Auth::Factory->new->from_config;
    my $store = ModelSEED::Store->new(auth => $auth);
    my $model = $self->_getModel($args, $store);
    my $helper = ModelSEED::App::Helpers->new();
    $self->usage_error("Model not found; You must supply a valid model name.") unless(defined($model));
    my $config = $opts->{config};
    unless(defined($config) && -f $config) {
        $self->usage_error("Must supply a configuration file for gapfilling");
    }
    my $exchange_factory = ModelSEED::MS::Factories::ExchangeFormatFactory->new();
    my $biochemistry = $model->biochemistry;
    my $gapfillingFormulation = $exchange_factory->fromFilename({
        filename => $config, biochemistry => $biochemistry
    });
    print "Gapfilling..." if($opts->{verbose});
    $model->gapfillModel({
        gapfillingFormulation => $gapfillingFormulation,
    });
    if($opts->{overwrite}) {
        # need _getModel to return ref as well
    }
    if($opts->{save}) {
        my $ref = $helper->process_ref_string($opts->{save}, "model", $auth->username);
        print "Saving gapfilled model to $ref" if($opts->{verbose});
        $model->save($ref);
    }


    $self->usage_error("Must specify an model to use") unless(defined($model));
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
