package ModelSEED::App::import::Command::model;
use base 'App::Cmd::Command';
use Class::Autouse qw(
    ModelSEED::Store
    ModelSEED::Auth::Factory
    ModelSEED::MS::Factories::FBAMODELFactory
    ModelSEED::Database::Composite
    ModelSEED::Reference
    ModelSEED::App::Helpers
);

sub abstract { return "Import an existing model"; }

sub usage_desc { return "ms import model [id] [alias] -a annotation [options]"; }
sub description { return <<END;
Models may be imported from the local database or from an existing
model on the ModelSeed website. To see a list of available models
for the given source use the --list flag:

    $ ms import model --list model-seed
    $ ms import model --list local

To import a model, supply the model's ID, the alias that you
would like to save it to and an annotation object to use:

    $ ms import model 83333.1 sdevoid/ecoli -a sdevoid/ecoli

If you would like to import a model from the local source, set
[ --source local ].

    $ ms import model 83333.1 sdevoid/ecoli --source local -a sdevoid/ecoli

END
}

sub opt_spec {
    return (
        ["source:s", "Source to import from, default is 'model-seed'"],
        ["list:s", "List models that are available to import from a soruce"], 
        ["annotation|a=s", "Annotation to use when importing the model"],
        ["mapping|m:s", "Select the mapping to use when importing the model"],
        ["biochemistry|b:s", "Select the biochemistry to use when importing the model"],
        ["store|s:s", "Identify which store to save the model to"],
        ["verbose|v", "Print detailed output of import status"],
        ["dry|d", "Perform a dry run; that is, do everything but saving"],
    );
}

sub execute {
    my ($self, $opts, $args) = @_;
    my $auth = ModelSEED::Auth::Factory->new->from_config();
    my $helpers = ModelSEED::App::Helpers->new();
    my $store;
    # Initialize the store object
    if($opts->{store}) {
        my $store_name = $opts->{store};
        my $config = ModelSEED::Configuration->instance;
        my $store_config = $config->config->{stores}->{$store_name};
        die "No such store: $store_name" unless(defined($store_config));
        my $db = ModelSEED::Database::Composite->new(databases => [ $store_config ]);
        $store = ModelSEED::Store->new(auth => $auth, database => $db);
    } else {
        $store = ModelSEED::Store->new(auth => $auth);
    }
    
    # Set source to 'model-seed' if it isn't defined
    $opts->{source} //= 'model-seed';
    my ($factory);
    if($opts->{source} eq 'model-seed') {
        $factory = ModelSEED::MS::Factories::FBAMODELFactory->new(
            auth => $auth,
            store => $store
        );
    } else {
        die "Unknown source: " . $opts->{source} . "\n";
    }
    # If we just want the list, print and exit
    if($opts->{list}) {
        if($opts->{source} eq 'model-seed') {
            my $ids = $factory->listAvailableModels();
            print join("\n", @$ids);
            return;
        } elsif($opts->{source} eq 'local') {
            ...
        }
    }
    # Now actual import stuff
    my ($id, $model_alias) = @$args;
    # Check that required arguments are present
    $self->usage_error("Must supply an id") unless(defined($id));
    $self->usage_error("Must supply an alias") unless(defined($model_alias));
    # Fix model ref string if we have to
    $model_alias = $helpers->process_ref_string($model_alias, "model", $auth->username);
    print "Will be saving to $model_alias...\n" if(defined($opts->{verbose}));
    my $alias_ref = ModelSEED::Reference->new(ref => $model_alias);
    my $config = { id => $id };
    # Fix annotation, mapping & biochemistry refs if we have to
    if(defined($opts->{annotation})) {
        $config->{annotation} = $opts->{annotation};
        $config->{annotation} = $helpers->process_ref_string(
            $config->{annotation}, "annotation", $auth->username);
    } else {
        $self->usage_error("Must supply and annotation");
    }
    if(defined($opts->{mapping})) {
        $config->{mapping} = $opts->{mapping};
        $config->{mapping} = $helpers->process_ref_string(
            $config->{mapping}, "mapping", $auth->username);
    }
    if(defined($opts->{biochemistry})) {
        $config->{biochemistry} = $opts->{biochemistry};
        $config->{biochemistry} = $helpers->process_ref_string(
            $config->{biochemistry}, "biochemistry", $auth->username);
    }
    $config->{verbose} = $opts->{verbose} if($opts->{verbose});
    my $model = $factory->createModel($config);
    unless($opts->{dry}) {
        $store->save_object($alias_ref, $model);
        print "Saved model to $model_alias!\n" if(defined($opts->{verbose}));
    }
}

1;
