package ModelSEED::CLI::stores::Command::list;
use ModelSEED::Config;
use Data::Dumper;
use base 'App::Cmd::Command';
sub abstract { "List current stores in order of priority" }
sub opt_spec {
    [ 'verbose|v', "print detailed configuration for each store" ],
}
sub execute {
    my ($self, $opt, $args) = @_;
    my $ms = ModelSEED::Config->new();    
    my $stores = $ms->config->{stores};
    if($opt->{verbose}) {
        print map { _detailed($_) . "\n" } @$stores;
    } else {
        print map { $_->{name} . "\n" } @$stores;
    }
}

sub _detailed {
    my ($s) = @_;
    # name    key=value key=value
    my $hide = { name => 1, class => 1 };
    my @attrs = grep { !$hide->{$_} } keys %$s;
    my $string = join(" ", map { $_ . '=' . $s->{$_} } @attrs);
    return $s->{name} . "\t" . $string;
}

1;
