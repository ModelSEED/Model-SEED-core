package ModelSEED::App::mseed::Command::list;
use Class::Autouse qw(
    ModelSEED::Configuration
    ModelSEED::Store
);
use base 'App::Cmd::Command';
use Data::Dumper;

sub execute {
    my ($self, $opts, $args) = @_;
    my $Config = ModelSEED::Configuration->new();
    my $username = $Config->config->{login}->{username};
    my $store  = ModelSEED::Store->new({
            username => $username,
            password => $Config->config->{login}->{password}
    });
    my $arg = shift @$args;
    my ($type) = _processRef($arg);
    my $aliases = $store->get_aliases_for_type($type);
    print join("\n", map { "$username/$_" } @$aliases) . "\n";
}

sub abstract {
    return "List and retrive objects from workspace or datastore.";
}

sub _processRef {
    my ($ref) = @_;
    return split(/\//, $ref);
}

1;
