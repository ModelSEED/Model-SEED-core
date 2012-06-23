package ModelSEED::App::import::Command::biochemistry;
use base 'App::Cmd::Command';
use File::Temp qw(tempfile);
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use LWP::Simple;
use Class::Autouse qw(
    ModelSEED::MS::Biochemistry
    ModelSEED::Store
    ModelSEED::Auth::Factory
    ModelSEED::App::Helpers
    ModelSEED::MS::Factories::PPOFactory
    ModelSEED::Database::Composite
    ModelSEED::Reference
);

sub abstract { return "Import biochemistry from local or remote database"; }

sub usage_desc { return "ms import biochemistry [alias] [-s store] [-l location]"; }
sub description { return <<END;
Import biochemistry data (compounds, reactions, media, compartments,
etc.) Alias, required, is the name that you would like to save the
biochemistry as.
    
The [--location name] argument indicates where you are importing
the biochemistry from. Current supported options are:
    
--location local      : import from local sqlite or MySQL database
--location model_seed : import standard biochemistry from the model_seed

END
}

sub opt_spec {
    return (
        ["location|l:s", "Where are you importing from. Defaults to 'model_seed'"],
        ["store|s:s", "Identify which store to save the biochemistry to"],
        ["verbose|v", "Print detailed output of import status"],
        ["dry|d", "Perform a dry run; that is, do everything but saving"],

    );
}

sub execute {
    my ($self, $opts, $args) = @_;
    my $auth = ModelSEED::Auth::Factory->new->from_config();
    my $helpers = ModelSEED::App::Helpers->new;
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
    # Check that required argument are present
    my ($alias) = @$args;
    $self->usage_error("Must supply an alias") unless(defined($alias));
    # Make sure the alias object is valid "username/alias_string"
    $alias = $helpers->process_ref_string($alias, "biochemistry", $auth->username);
    print "Will be saving to $alias...\n" if($opts->{verbose});
    my $alias_ref = ModelSEED::Reference->new(ref => $alias);
    my $bio;
    if($opts->{location} && $opts->{location} eq 'local') {
        # Cannot go further unless we're using basic auth (legacy)
        unless(ref($auth) && $auth->isa("ModelSEED::Auth::Basic")) {
            $self->usage_error("Cannot import from local unless you are logged in")
        }
        # Get the biochemistry object from the local PPO
        my $figmodel = ModelSEED::FIGMODEL->new({
            username => $auth->username,
            password => $auth->password,
        });
        my $factory = ModelSEED::MS::Factories::PPOFactory->new({
            figmodel => $figmodel,
            namespace => $auth->username,
        });
        $bio = $factory->createBiochemistry({
                name => $alias,
                addAliases => 1,
                addStructuralCues => 1,
                addStructure => 1,
                addPk => 1,
                verbose => $opts->{verbose},
        });
    } else {
        # Just fetch a pre-built biochemistry from the web
        my $url = "http://bioseed.mcs.anl.gov/~devoid/json_objects/FullBiochemistry.json.gz";
        my $data;
        {
            my ($fh1, $compressed_filename) = tempfile();
            my ($fh2, $uncompressed_filename) = tempfile();
            close($fh1);
            close($fh2);
            print "Fetching biochemistry from web...\n" if($opts->{verbose});
            my $status = getstore($url, $compressed_filename);
            # This should probably be >= 200 <= 400? does getstore handle redirects?
            die "Unable to fetch from model_seed\n" unless($status == 200);
            print "Extracting...\n" if($opts->{verbose});
            gunzip $compressed_filename => $uncompressed_filename
                or die "Extract failed: $GunzipError\n";

            my $string;
            {
                local $/;
                open(my $fh, $uncompressed_filename) || die "$!: $@";
                $string = <$fh>;
            }
            $data = JSON->new->utf8->decode($string);
        }
        print "Validating fetched biochemistry...\n" if($opts->{verbose});
        $bio = ModelSEED::MS::Biochemistry->new($data);
    }
    unless($opts->{dry}) {
        $store->save_object($alias_ref, $bio);
    }
    print "Saved biochemistry to $alias!\n" if($opts->{verbose});
}

1;
