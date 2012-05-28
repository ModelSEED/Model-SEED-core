package ModelSEED::App::mseed::Command::logout;
use base 'App::Cmd::Command';
use ModelSEED::Configuration;

sub abstract { return "Log out" }
sub execute {
    my ($self, $opts, $args) = @_;
    my $conf = ModelSEED::Configuration->new();
    delete $conf->config->{login};
    $conf->save();
}

1;
