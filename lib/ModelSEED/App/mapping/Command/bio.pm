package ModelSEED::App::mapping::Command::bio;
use base 'App::Cmd::Command';
use Try::Tiny;
use Class::Autouse qw(
    ModelSEED::Store
    ModelSEED::Auth::Factory
    ModelSEED::Reference
    ModelSEED::Configuration
    ModelSEED::App::Helpers
);
sub abstract { return "Returns the associated biochemistry object" }
sub usage_desc { return <<END;
mapping bio [ reference ] [options]
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
    my $map = $self->_getMapping($args, $store);
    $self->usage_error("Must specify an annotation to use") unless(defined($map));
    my $ref;
    if ($opts->{raw} || $opts->{full}) {
        $ref = ModelSEED::Reference->new(
            type => "bichemistry",
            uuid => $map->{biochemistry_uuid}
        );
    }
    if ($opts->{raw}) {
        my $d = $store->get_data($ref);
        print JSON->new->utf8(1)->encode($d);
    } elsif($opts->{full}) {
        my $bio = $store->get_object($ref);
        print join("\n", @{$bio->createReadableStringArray}) . "\n";
    } else {
        print "biochemistry/". $map->{biochemistry_uuid} . "\n";
    }
}

sub _getMapping {
    my ($self, $args, $store) = @_;
    my $helper = ModelSEED::App::Helpers->new();
    $ref = $helper->get_base_ref("mapping", $args);
    if(defined($ref)) {
        return $store->get_data($ref);
    }
}

1;
