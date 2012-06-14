=pod

=head1 anno roles

Testing using Pod

=cut
package ModelSEED::App::genome::Command::subsystems;
use base 'App::Cmd::Command';
use Try::Tiny;
use Class::Autouse qw(
    ModelSEED::Store
    ModelSEED::Auth::Factory
    ModelSEED::Reference
    ModelSEED::Configuration
);
sub abstract { return "Get the list of roles for an annotated genome" }
sub usage_desc { return <<END;
genome roles [ options ]

END
}

sub opt_spec {
    return ();
}

sub execute {
    my ($self, $opts, $args) = @_;
    my $annotation = $self->_getAnnotation($args);
    $self->usage_error("Must specify an annotation to use") unless(defined($annotation));
    print map { $_->type . "\t" . $_->name ."\n" } @{$annotation->subsystems};
}

sub _getAnnotation {
    my ($self, $args) = @_;
    my $arg = shift @$args; 
    my ($ref, $anno);
    if($arg =~ /annotation/) {
        $ref = ModelSEED::Reference->new(ref => $arg);
    } else {
        unshift @$args, $arg;
    }
    if(!defined($ref) && ! -t STDIN) {
        my $str = <STDIN>;
        chomp $str;
        $ref = ModelSEED::Reference->new(ref => $arg);
     }
     if(!defined($ref)) {
         my $config = ModelSEED::Configuration->instance;
         $ref = $config->config->{annochemistry};
     }
     my $auth  = ModelSEED::Auth::Factory->new->from_config;
     my $store = ModelSEED::Store->new(auth => $auth);
     if(defined($ref)) {
         $anno = $store->get_object($ref);
     }
     return $anno;
}

1;
