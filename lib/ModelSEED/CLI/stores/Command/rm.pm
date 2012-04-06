package ModelSEED::CLI::stores::Command::rm;
use ModelSEED::Config;
use base 'App::Cmd::Command';


my $MS = ModelSEED::Config->new();

sub abstract { "Remove a storage interface" }
sub usage_desc { "%c remove <name>" }

sub validate_args {
    my ($self, $opt, $args) = @_;
    unless(@$args == 1) {
        $self->usage_error("Must supply a storage interface to remove");
    }
    my $name = $args->[0];
    unless(defined($MS->config->{stores})) {
        $self->usage_error("No storage interface $name found");
    }
    my $map = { map { $_->{name} => $_ } @{$MS->config->{stores}} };
    unless(defined($map->{$name})) {
        $self->usage_error("No storage interface $name found");
    }
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $name = $args->[0];
    my $stores = $MS->config->{stores};
    my $remove;
    for(my $i=0; $i<@$stores; $i++) {
        $remove = $i if $stores->[$i]->{name} eq $name;
        last if defined $remove; 
    }
    splice(@$stores, $remove, 1);
    $MS->config->{stores} = $stores;
    $MS->save;
}

1;
