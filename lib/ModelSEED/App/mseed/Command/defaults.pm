package ModelSEED::App::mseed::Command::defaults;
use Try::Tiny;
use List::Util qw(max);
use Class::Autouse qw(
    ModelSEED::Configuration
    ModelSEED::Reference
);
use base 'App::Cmd::Command';

sub abstract { return "List and set default objects and aliases"; }
sub usage_desc {
    return <<END;
ms defaults [ parameter [--set value ] ]
END
}
sub opt_spec {
    return (
        ["set|s:s", "Set default attribute to string value"],
        ["unset", "Remove attribute value"],
    );
}

sub execute {
    my ($self, $opts, $args) = @_;
    my $blessed_params = {
        "biochemistry.alias.set" => \&_string,
        biochemistry => \&_ref,
        mapping => \&_ref,
        model => \&_ref,
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
    } elsif(defined($arg) && defined($opts->{set})) {
        my $value = $opts->{set};
        die "Invalid value $value for $arg" unless($blessed_params->{$arg}->($value));
        $config->config->{$arg} = $opts->{set};
        $config->save;
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
