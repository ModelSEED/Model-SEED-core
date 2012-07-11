package ModelSEED::App::mseed::Command::whoami;
use base 'App::Cmd::Command';
use ModelSEED::Configuration;

sub abstract { return "Return the currently logged in user" }
sub execute {
    my ($self, $opts, $args) = @_;
    my $conf = ModelSEED::Configuration->new();
    my $username = $conf->config->{login}->{username};
    $username = "public" unless(defined($username));
    print $username ."\n";
}


1;
