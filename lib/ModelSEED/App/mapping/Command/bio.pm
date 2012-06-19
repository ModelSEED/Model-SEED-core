package ModelSEED::App::mapping::Command::bio;
use base 'App::Cmd::Command';
use Class::Autouse qw(
    ModelSEED::Store
    ModelSEED::Auth::Factory
    ModelSEED::App::Helpers
);
sub abstract { return "Returns the associated biochemistry object" }
sub usage_desc { return "mapping bio [< name | name ] [options]" }
sub opt_spec { 
    return (
        ["raw|r", "Return raw JSON output"],
        ["full", "Return the full bio object in a readable form"],
    );
}

sub execute {
    my ($self, $opts, $args) = @_;
    my $auth  = ModelSEED::Auth::Factory->new->from_config;
    my $store = ModelSEED::Store->new(auth => $auth);
    my $helpers = ModelSEED::App::Helpers->new();
    my $map = $helpers->get_object($args, "mapping", $store);
    $self->usage_error("Must specify a mapping to use") unless(defined($map));
    print $helpers->handle_ref_lookup(
        $store, $map, "biochemistry_uuid", "biochemistry", $opts
    );
}
1;
