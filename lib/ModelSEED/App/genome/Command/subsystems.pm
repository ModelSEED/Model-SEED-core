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
sub usage_desc { return "genome roles [ options ]" }
sub execute {
    my ($self, $opts, $args) = @_;
    my $auth = ModelSEED::Auth::Factory::new->from_config;
    my $store = ModelSEED::Store->new(auth => $auth);
    my $helpers = ModelSEED::App::Helpers->new;
    my ($annotation, $annoRef) = $helpers->get_object("annotation", $args, $store);
    $self->usage_error("Must specify an annotation to use") unless(defined($annotation));
    print map { $_->type . "\t" . $_->name ."\n" } @{$annotation->subsystems};
}

1;
