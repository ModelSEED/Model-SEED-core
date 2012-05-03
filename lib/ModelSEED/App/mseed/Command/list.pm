package ModelSEED::App::mseed::Command::list;
use Class::Autouse qw(
    ModelSEED::Configuration
    ModelSEED::ObjectManager
    ModelSEED::PersistenceAPI
);
use base 'App::Cmd::Command';
use Data::Dumper;

sub execute {
    my ($self, $opts, $args) = @_;
    my $Config = ModelSEED::Configuration->new();
    my $stores = [];
    foreach my $store (@{$Config->config->{stores}}) {
        my $class = $store->{class};
        my %config = %$store;
        delete $config{"class"}; 
        push(@$stores, ModelSEED::PersistenceAPI->new({ db_class => $class, db_config => \%config }));
    }
    print Dumper $stores;
}

sub abstract {
    return "List and retrive objects from workspace or datastore.";
}

1;
