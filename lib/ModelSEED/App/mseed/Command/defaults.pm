package ModelSEED::App::mseed::Command::defaults;
use Try::Tiny;
use List::Util qw(max);
use Class::Autouse qw(
    ModelSEED::Configuration
    ModelSEED::Reference
);
use base 'App::Cmd::Command';

sub abstract { return "List and set default objects and aliases"; }
sub usage_desc { return "ms defaults [ parameter [--set value ] ]"; }
sub description { return <<END;
Set the default object to use commands if no reference is passed.
Valid object parameters include:

    biochemistry.alias.set  - the ids to use for reactions and compounds
    biochemistry            - which biochemistry to use 
    mapping                 - which mapping to use
    model                   - which model to use
    annotation              - whcih annotated genome to use
END
}
sub opt_spec {
    return (
        ["set|s:s", "Set default attribute to string value"],
        ["unset|u", "Remove attribute value"],
    );
}

sub execute {
    my ($self, $opts, $args) = @_;
    my $blessed_params = {
        "biochemistry.alias.set" => \&_string,
        biochemistry => \&_ref,
        mapping => \&_ref,
        model => \&_ref,
        annotation => \&_ref,
    };
    my $max_string_size = max map { length $_ } keys %$blessed_params;
    my $config = ModelSEED::Configuration->new;
    my $arg = shift @$args;
    if(!defined($arg)) {
        foreach my $param (keys %$blessed_params) {
            my $value = $config->config->{$param};
            if(!defined($value)) {
                $value = "undefined"
            }
            printf("%-${max_string_size}s\t%s\n", ($param, $value));
        }
    } elsif(defined($arg) && $opts->{unset}) {
        $config->config->{$arg} = undef;
        $config->save;
    } elsif(defined($arg)) {
        $self->usage_error("Unknown default name: $arg") unless(defined($blessed_params->{$arg}));
        if(defined($opts->{set})) {
            my $value = $opts->{set};
            $self->usage_error("Invalid value $value for $arg") unless($blessed_params->{$arg}->($value));
            $config->config->{$arg} = $opts->{set};
            $config->save;
        } elsif(defined($opts->{unset})) {
            delete $config->config->{$arg};
            $config->save;
        } else {
            print $config->config->{$arg} . "\n";
        }
    }
}

sub _string {
    return 1 if(defined($_[0]));
}
sub _ref {
    my ($ref) = @_;
    my $ref2;
    try {
        $ref2 = ModelSEED::Reference->new(ref => $ref);
    };
    return 1 if(defined($ref2));
}

1;
