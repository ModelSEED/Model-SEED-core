package ModelSEED::App::import::Command::annotation;
use base 'App::Cmd::Command';
use Class::Autouse qw(
    ModelSEED::Store
    ModelSEED::Auth::Factory
    ModelSEED::App::Helpers
    ModelSEED::MS::Factories::Annotation
    ModelSEED::Database::Composite
    ModelSEED::Reference
);

sub abstract { return "Import annotation from the SEED or RAST"; }

sub usage_desc { return "ms import annotation [id] [alias] [-m mapping]"; }
sub description { return <<END;
An annotated genome may be imported from the SEED or RAST annotation
service.  To see a list of available models use the --list flag. 
For a tab-delimited list of genome ids and names add
the --verbose flag:

    $ ms import annotation --list 
    $ ms import annotation --list --verbose

You may restrict your search to a specific source with the --source flag.
This also works when importing by a given ID. The current available sources are:

    "PubSEED" (pubseed.theseed.org) - The Public SEED
    "RAST" (rast.nmpdr.org) - Note that listing is currently not available with this.
    "KBASE" (kbase.us) - Systems Biology Knowledgebase

To import an annotated genome, supply the genome's ID, the alias that
you would like to save it to and a mapping object to use:
    
    $ ms import annotation 83333.1 ecoli -m main

If no mapping is supplied, the default mapping will be used:

    $ ms defaults mapping
END
}

sub opt_spec {
    return (
        ["list|l",    "List available annotated genomes"],
        ["source:s", "Restrict search to a specific data source"],
        ["store|s:s", "Identify which store to save the annotation to"],
        ["verbose|v", "Print detailed output of import status"],
        ["dry|d", "Perform a dry run; that is, do everything but saving"],
        ["mapping|m:s", "Select the preferred mapping object to use when importing the annotation"],
    );
}

sub execute {
    my ($self, $opts, $args) = @_;
    my $auth = ModelSEED::Auth::Factory->new->from_config();
    my $helper = ModelSEED::App::Helpers->new;
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
    my $factory = ModelSEED::MS::Factories::Annotation->new(om => $store);
    my $sources = [ $opts->{source} ];
    $sources = [ qw(PubSEED RAST KBase) ] unless(@$sources);
    # If we are listing, just do that and exit
    if(defined($opts->{list})) {
        $self->printList($factory, $opts);
        exit;
    }
    # Check that required arguments are present
    my ($id, $alias) = @$args;
    $self->usage_error("Must supply an id") unless(defined($id));
    $self->usage_error("Must supply an alias") unless(defined($alias));
    # Make sure the alias object is valid "username/alias_string"
    $alias = $helper->process_ref_string(
        $alias, "annotation", $auth->username
    );
    print "Will be saving to $alias...\n" if(defined($opts->{verbose}));
    my $alias_ref = ModelSEED::Reference->new(ref => $alias);
    # Get the annotation object
    my $config = { genome_id => $id };
    $config->{verbose} = $opts->{verbose} if(defined($opts->{verbose}));
    if(defined($opts->{mapping})) {
        my $mapping_alias = $helper->process_ref_string(
            $opts->{mapping}, "mapping", $auth->username
        );
        print "Fetching $mapping_alias...\n" if(defined($opts->{verbose}));
        my $mapping_ref = ModelSEED::Reference->new(ref => $mapping_alias);
        $config->{mapping} = $store->get_object($mapping_ref);
    }
    print "Getting annotation...\n" if(defined($opts->{verbose}));
    my $anno = $factory->build($config);
    unless($opts->{dry}) {
        my $mapping = $anno->mapping;
        my $mapping_ref = ModelSEED::Reference->new( type => "mapping", uuid => $mapping->uuid );
        my $uuid = $store->save_object($mapping_ref, $mapping);
        $anno->mapping_uuid($uuid);
        $store->save_object($alias_ref, $anno);
        print "Saved annotation to $alias!\n" if(defined($opts->{verbose}));
    }
}

sub printList {
    my ($self, $factory, $opts) = @_;
    my $sources = [ $opts->{source} ];
    $sources = [ qw(PUBSEED KBase) ] unless $sources->[0];
    foreach my $source (@$sources) {
        my $genomeHash = $factory->availableGenomes({source => $source});
        if($opts->{verbose}) {
            print join( "\n",
                map { $_ = "$_\t" . $genomeHash->{$_} }
                  keys %$genomeHash )
              . "\n";
        } else {
            print join("\n", keys %$genomeHash) . "\n";
        }
    }
}

1;
