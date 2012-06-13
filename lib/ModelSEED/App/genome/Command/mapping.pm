package ModelSEED::App::genome::Command::mapping;
use base 'App::Cmd::Command';
use Try::Tiny;
use Class::Autouse qw(
    ModelSEED::Store
    ModelSEED::Auth::Factory
    ModelSEED::Reference
    ModelSEED::Configuration
    ModelSEED::App::Helpers
);
sub abstract { return "Returns the associated mapping object" }
sub usage_desc { return <<END;
genome mapping [ reference ] [options]
END
}
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
    my $annotation = $self->_getAnnotation($args, $store);
    $self->usage_error("Must specify an annotation to use") unless(defined($annotation));
    my $ref;
    if ($opts->{raw} || $opts->{full}) {
        $ref = ModelSEED::Reference->new(
            type => "mapping",
            uuid => $annotation->{mapping_uuid}
        );
    }
    if ($opts->{raw}) {
        my $d = $store->get_data($ref);
        print JSON->new->utf8(1)->encode($d);
    } elsif($opts->{full}) {
        my $mapping = $store->get_object($ref);
        print join("\n", @{$mapping->createReadableStringArray}) . "\n";
    } else {
        print "mapping/". $annotation->{mapping_uuid} . "\n";
    }
}

sub _getAnnotation {
    my ($self, $args, $store) = @_;
    my $helper = ModelSEED::App::Helpers->new();
    $ref = $helper->get_base_ref("annotation", $args);
    if(defined($ref)) {
        return $store->get_data($ref);
    }
}

1;
