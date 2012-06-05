package ModelSEED::App::import::Command::annotation;
use base 'App::Cmd::Command';
use Class::Autouse qw(
    ModelSEED::Store
    ModelSEED::Auth::Factory
    ModelSEED::MS::Factories::SEEDFactory
    ModelSEED::Database::Composite
    ModelSEED::Reference
);

sub abstract { return "Import annotation from the SEED or RAST"; }

sub usage_desc { return <<END;
ms import annotation [id] [alias] [-s store] [-m mapping]
Import a RAST or SEED genome with "id" to the current enviornemnt
as "alias". If store is povided, save in with that storage interface.

END
}

sub opt_spec {
    return (
        ["store|s:s", "Identify which store to save the annotation to"],
        ["verbose|v", "Print detailed output of import status"],
        ["dry|d", "Perform a dry run; that is, do everything but saving"],
        ["mapping|m:s", "Select the preferred mapping object to use when importing the annotation"],
    );
}

sub execute {
    my ($self, $opts, $args) = @_;
    my $store;
    my $auth = ModelSEED::Auth::Factory->new->from_config();
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
    # Check that required arguments are present
    my ($id, $alias) = @$args;
    $self->usage_error("Must supply an id") unless(defined($id));
    $self->usage_error("Must supply an alias") unless(defined($alias));
    # Make sure the alias object is valid "username/alias_string"
    my ($uname, $alias_string) = split(/\//, $alias);
    unless(defined($alias_string) && $uname eq $auth->username) {
        if(defined($alias_string)) {
            $alias = $auth->username . "/" . $alias_string;
        } else {
            $alias = $auth->username . "/" . $uname;
        }
    }
    $alias = "annotation/$alias";
    print "Will be saving to $alias...\n" if(defined($opts->{verbose}));
    my $alias_ref = ModelSEED::Reference->new(ref => $alias);
    # Get the annotation object
    my $factory = ModelSEED::MS::Factories::SEEDFactory->new(om => $store);
    my $config = { genome_id => $id };
    $config->{verbose} = $opts->{verbose} if(defined($opts->{verbose}));
    if(defined($opts->{mapping})) {
        my $mapping_alias = $opts->{mapping};
        $mapping_alias = "mapping/" . $mapping_alias unless($mapping_alias =~ /^mapping\//);
        print "Fetching $mapping_alias...\n" if(defined($opts->{verbose}));
        my $mapping_ref = ModelSEED::Reference->new(ref => $mapping_alias);
        $config->{mapping} = $store->get_object($mapping_ref);
    }
    print "Getting annotation...\n" if(defined($opts->{verbose}));
    my $anno = $factory->buildMooseAnnotation($config);

    unless($opts->{dry}) {
        $store->save_object($alias_ref, $anno);
        print "Saved annotation to $alias!\n" if(defined($opts->{verbose}));
    }
}

1;
