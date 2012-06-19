package ModelSEED::App::model::Command::genome;
use base 'App::Cmd::Command';
use Try::Tiny;
use Class::Autouse qw(
    ModelSEED::Store
    ModelSEED::Auth::Factory
    ModelSEED::App::Helpers
);
sub abstract { return "Returns the associated annotation object" }
sub usage_desc { return "model genome [ reference ] [options]" }
sub opt_spec { 
    return (
        ["raw|r", "Return raw JSON output"],
        ["full", "Return the full annotation object in a readable form"],
    );
}

sub execute {
    my ($self, $opts, $args) = @_;
    my $auth  = ModelSEED::Auth::Factory->new->from_config;
    my $store = ModelSEED::Store->new(auth => $auth);
    my $helper= ModelSEED::App::Helpers->new();
    my $model = $helper->get_object($args, "model", $store);
    $self->usage_error("Must specify a model to use") unless(defined($model));
    print $helper->handle_ref_lookup(
        $store, $model, "annotation_uuid", "annotation", $opts
    );
}
1;
