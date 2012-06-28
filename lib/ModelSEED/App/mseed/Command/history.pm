package ModelSEED::App::mseed::Command::history;
use Try::Tiny;
use List::Util;
use Class::Autouse qw(
    ModelSEED::App::Helpers
    ModelSEED::Reference
    ModelSEED::Auth::Factory
    ModelSEED::Store
    JSON
);
use base 'App::Cmd::Command';

sub abstract { return "Return references to all previous versions of an object."; }
sub usage_desc { return "ms get [reference || - < STDIN ] [options]"; }
sub opt_spec {
    return (
        ["date|d", "Include a timestamp for when the objects was saved"],
    );
}
sub description { return <<END;
Return a list of references to all previous versions of an object.

END
}

sub execute {
    my ($self, $opts, $args) = @_;
    my $auth = ModelSEED::Auth::Factory->new->from_config;
    my $store = ModelSEED::Store->new(auth => $auth);
    my $helpers = ModelSEED::App::Helpers->new;
    my ($ref, $type);
    $ref = $helpers->get_base_ref("*", $auth->username, $args);
    $self->usage_error("Must supply a valid reference") unless(defined($ref));
    $type = $ref->base_types->[0];
    my $unseen_ancestors = [$ref->ref];
    my $seen_ancestors = {};
    my $list = [];
    while(my $ancestor = shift @$unseen_ancestors) {
        $seen_ancestors->{$ancestor} = 1;
        my $object = $store->get_data($ancestor);
        next unless(defined($object));
        my $values = [ $ancestor ];
        push(@$values, $object->{modDate}) if($opts->{date});
        print join("\t", @$values) . "\n";
        my $refs = [
            map { $_->ref }
            map { ModelSEED::Reference->new( uuid => $_, type => $type ) }
                @{ $object->{ancestor_uuids} || [] }
        ];
        foreach my $ref (@$refs) {
            next if defined($seen_ancestors->{$ref});
            push(@$unseen_ancestors, $ref);
        }
    }
}

1;
