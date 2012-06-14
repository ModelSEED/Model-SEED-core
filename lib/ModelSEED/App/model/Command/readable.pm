package ModelSEED::App::model::Command::readable;
use base 'App::Cmd::Command';
use Try::Tiny;
use Class::Autouse qw(
    ModelSEED::Store
    ModelSEED::Auth::Factory
    ModelSEED::Reference
    ModelSEED::Configuration
    ModelSEED::App::Helpers
);
sub abstract { return "Prints a readable format for the object" }
sub usage_desc { return <<END;
model readable [ model-name ]
END
}

sub execute {
    my ($self, $opts, $args) = @_;
    my $model = $self->_getModel($args);
    $self->usage_error("Must specify an model to use") unless(defined($model));
    print join("\n", @{$model->createReadableStringArray});
}

sub _getModel {
    my ($self, $args) = @_;
    my $helper = ModelSEED::App::Helpers->new();
    $ref = $helper->get_base_ref("model", $args);
    if(defined($ref)) {
        my $auth  = ModelSEED::Auth::Factory->new->from_config;
        my $store = ModelSEED::Store->new(auth => $auth);
        return $store->get_object($ref);
    }
}

1;
