package ModelSEED::App::model::Command::readable;
use base 'App::Cmd::Command';
use Class::Autouse qw(
    ModelSEED::Store
    ModelSEED::Auth::Factory
    ModelSEED::App::Helpers
);
sub abstract { return "Prints a readable format for the object" }
sub usage_desc { return "model readable [< name | name]" }
sub execute {
    my ($self, $opts, $args) = @_;
    my $auth  = ModelSEED::Auth::Factory->new->from_config;
    my $store = ModelSEED::Store->new(auth => $auth);
    my $helper = ModelSEED::App::Helpers->new();
    my ($model, $modelRef) = $helper->get_object("model", $args, $store);
    $self->usage_error("Must specify an model to use") unless(defined($model));
    print join("\n", @{$model->createReadableStringArray});
}
1;
