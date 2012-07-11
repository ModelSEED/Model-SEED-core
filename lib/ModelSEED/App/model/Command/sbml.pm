package ModelSEED::App::model::Command::sbml;
use base 'App::Cmd::Command';
use Try::Tiny;
use Class::Autouse qw(
    ModelSEED::Store
    ModelSEED::Auth::Factory
    ModelSEED::App::Helpers
);
sub abstract { return "Print SBML version of the model" }
sub usage_desc { return <<END;
model sbml [ reference || - ]
END
}

sub execute {
    my ($self, $opts, $args) = @_;
    my $auth  = ModelSEED::Auth::Factory->new->from_config;
    my $store = ModelSEED::Store->new(auth => $auth);
    my $helper = ModelSEED::App::Helpers->new();
    my ($model, $ref) = $helper->get_object("model", $args, $store);
    $self->usage_error("Must specify an model to use") unless(defined($model));
    print join("\n", @{$model->printSBML()});
}

1;
