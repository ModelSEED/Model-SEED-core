package ModelSEED::App::bio::Command::readable;
use base 'App::Cmd::Command';
use Class::Autouse qw(
    ModelSEED::Store
    ModelSEED::Auth::Factory
    ModelSEED::App::Helpers
);
sub abstract { return "Prints a readable format for the object" }
sub usage_desc { return "bio readable [< name | name]" }
sub execute {
    my ($self, $opts, $args) = @_;
    my $auth  = ModelSEED::Auth::Factory->new->from_config;
    my $store = ModelSEED::Store->new(auth => $auth);
    my $helper = ModelSEED::App::Helpers->new();
    my $biochemistry = $helper->get_object("biochemistry", $args, $store);
    $self->usage_error("Must specify an biochemistry to use") unless(defined($biochemistry));
    print join("\n", @{$biochemistry->createReadableStringArray});
}
1;
