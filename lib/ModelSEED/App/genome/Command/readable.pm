package ModelSEED::App::genome::Command::readable;
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
function readable
END
}

sub execute {
    my ($self, $opts, $args) = @_;
    my $annotation = $self->_getAnnotation($args);
    $self->usage_error("Must specify an annotation to use") unless(defined($annotation));
    print join("\n", @{$annotation->createReadableStringArray});
}

sub _getAnnotation {
    my ($self, $args) = @_;
    my $helper = ModelSEED::App::Helpers->new();
    $ref = $helper->get_base_ref("annotation", $args);
    if(defined($ref)) {
        my $auth  = ModelSEED::Auth::Factory->new->from_config;
        my $store = ModelSEED::Store->new(auth => $auth);
        return $store->get_object($ref);
    }
}

1;
