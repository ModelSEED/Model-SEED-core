package ModelSEED::App::mapping::Command::readable;
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
mapping readable [reference] [options]
END
}

sub execute {
    my ($self, $opts, $args) = @_;
    my $mapping = $self->_getMapping($args);
    $self->usage_error("Must specify an mapping to use") unless(defined($mapping));
    print join("\n", @{$mapping->createReadableStringArray});
}

sub _getMapping {
    my ($self, $args) = @_;
    my $helper = ModelSEED::App::Helpers->new();
    $ref = $helper->get_base_ref("mapping", $args);
    if(defined($ref)) {
        my $auth  = ModelSEED::Auth::Factory->new->from_config;
        my $store = ModelSEED::Store->new(auth => $auth);
        return $store->get_object($ref);
    }
}

1;
