package ModelSEED::App::stores::Command::rm;
use Class::Autouse qw(ModelSEED::Configuration);
use base 'App::Cmd::Command';


my $MS = ModelSEED::Configuration->new();
sub abstract { "Remove a storage interface" }
sub description { return <<HERDOC;
Remove a storage interface from the list of interfaces available.
Removing an iterface does not affect data stored with that interface.
HERDOC
}
sub usage_desc { "%c rm <name>" }
sub command_names { qw(rm remove) }

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
