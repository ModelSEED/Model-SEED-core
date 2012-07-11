package ModelSEED::App::genome::Command::mapping;
use base 'App::Cmd::Command';
use Class::Autouse qw(
    ModelSEED::Store
    ModelSEED::Auth::Factory
    ModelSEED::App::Helpers
);
sub abstract { return "Returns the associated mapping object" }
sub usage_desc { return "genome mapping [< name | name] [options]" }
sub opt_spec { 
    return (
        ["raw|r", "Return raw JSON output"],
        ["full", "Return the full mapping object in a readable form"],
    );
}

sub execute {
    my ($self, $opts, $args) = @_;
    my $auth  = ModelSEED::Auth::Factory->new->from_config;
    my $store = ModelSEED::Store->new(auth => $auth);
    my $helpers = ModelSEED::App::Helpers->new();
    my ($anno, $annoRef) = $helpers->get_object("annotation", $args, $store);
    $self->usage_error("Must specify an annotation to use") unless(defined($anno));
    print $helpers->handle_ref_lookup(
        $store, $anno, "mapping_uuid", "mapping", $opts
    );
}
1;
