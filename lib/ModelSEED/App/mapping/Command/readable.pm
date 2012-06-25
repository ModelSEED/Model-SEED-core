package ModelSEED::App::mapping::Command::readable;
use base 'App::Cmd::Command';
use Class::Autouse qw(
    ModelSEED::Store
    ModelSEED::Auth::Factory
    ModelSEED::App::Helpers
);
sub abstract { return "Prints a readable format for the object" }
sub usage_desc { return "mapping readable [< name | name]" }
sub execute {
    my ($self, $opts, $args) = @_;
    my $auth  = ModelSEED::Auth::Factory->new->from_config;
    my $store = ModelSEED::Store->new(auth => $auth);
    my $helper = ModelSEED::App::Helpers->new();
    my ($mapping, $mapRef) = $helper->get_object("mapping", $args, $store);
    $self->usage_error("Must specify an mapping to use") unless(defined($mapping));
    print join("\n", @{$mapping->createReadableStringArray});
}
1;
