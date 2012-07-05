package ModelSEED::App::genome::Command::buildModel;
use base 'App::Cmd::Command';
use Class::Autouse qw(
    ModelSEED::Store
    ModelSEED::Auth::Factory
    ModelSEED::App::Helpers
);
sub abstract { return "Construct a model using this annotated genome" }
sub usage_desc { return "genome buildModel [ reference || - ] [model-name]"; }
sub opt_spec {
    return (
        ["mapping|m", "Use a specific mapping to build the model"],
        ["verbose|v", "Print verbose about the model construction"],
    );
}

sub description { return <<END;
This function constructs a basic model from the annotated genome.
If no mapping object is supplied, it uses the mapping object
associated with the annotated genome. model-name is the name of the
resulting model.

    \$ genome buildModel my-genome my-model
END
}

sub execute {
    my ($self, $opts, $args) = @_;
    my $auth  = ModelSEED::Auth::Factory->new->from_config;
    my $store = ModelSEED::Store->new(auth => $auth);
    my $helpers = ModelSEED::App::Helpers->new();
    my $anno_ref = $helpers->process_ref_string(shift @$args, "annotation", $auth->username);
    my $model_ref = $helpers->process_ref_string(shift @$args, "model", $auth->username);
    unless(defined($anno_ref)) {
        $self->usage_error("Must specify an annotation to use");
    }
    unless(defined($model_ref)) {
        $self->usage_error("Must supply a name for model");
    }
    my $annotation = $store->get_object($anno_ref);
    unless(defined($annotation)) {
        $self->usage_error("Annotation " . $anno_ref->ref . " not found");
    }
    my $mapping;
    if(defined($opts->{mapping})) {
        $mapping = $helpers->process_ref_string($opts->{mapping}, "mapping", $auth->username);
        $mapping = $store->get_object($mapping);
    } else {
        $mapping = $annotation->mapping;
    }
    my $verbose = (defined $opts->{verbose}) ? 1 : 0;
    my $model = $annotation->createStandardFBAModel({
        mapping => $mapping, verbose => $verbose
    });
    die "Unable to create model: $model_ref\n" unless($model_ref);
    $model_ref = $helpers->process_ref_string($model_ref, "model", $auth->username);
    my $rtv = $store->save_object($model_ref, $model);
    if($rtv) {
        print "Saved model to $model_ref\n";
        return;
    }
    die "Unable to create model: $model_ref\n" unless($model_ref);
}

1;
