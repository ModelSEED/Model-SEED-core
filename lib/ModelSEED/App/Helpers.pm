package ModelSEED::App::Helpers;
use Class::Autouse qw(
    ModelSEED::Reference
    ModelSEED::Configuration
);
sub new {
    my $self = {};
    bless $self;
    return $self;
}

sub process_ref_string {
    my ($self, $refString, $type, $username) = @_;
    my $count = split(/\//, $refString);
    if ($refString =~ /^$type\//) {
        # string is fine, do nothing
    } elsif($count == 1) {
        # alais_string, add username and type
        $refString = "$type/$username/$refString"
    } elsif($count == 2) {
        # full alias, just add type
        $refString = "$type/$refString";
    }
    return $refString;
}

sub get_base_ref {
    my ($self, $type, $args, $options) = @_;
    my $ref;
    my $from_stdin  = $options->{stdin} // 1;
    my $from_config = $options->{config} // 1;
    my $from_argv   = $options->{argv} // 1;
    my $arg = shift @$args;
    if($from_argv && $arg =~ /^$type\//) {
        $ref = ModelSEED::Reference->new(ref => $arg);
    } elsif($from_argv && $arg && $arg ne '-') {
        $ref = ModelSEED::Reference->new(ref => "$type/$arg");
    } elsif($from_argv && $from_stdin && $arg && $arg eq '-' && ! -t STDIN) {
        my $str = <STDIN>;
        chomp $str;
        if($str =~ /^$type\//) {
            $ref = ModelSEED::Reference->new(ref => $str);
        } else {
            $ref = ModelSEED::Reference->new(ref => "$type/$str");
        }
    } else {
        unshift @$args, $arg;
    }
    if(!defined($ref) && $from_config) {
        my $config = ModelSEED::Configuration->instance;
        $ref = $config->config->{$type};
        $ref = ModelSEED::Reference->new(ref => $ref);
    }
    return $ref;
}

sub get_base_refs {
    my ($self, $type, $args, $options) = @_;
    my $refs = [];
    my $from_stdin  = $options->{stdin} // 1;
    my $from_config = $options->{config} // 1;
    my $from_argv   = $options->{argv} // 1;
    if($from_argv) {
        foreach my $arg (@$args) {
            if($arg =~ /^$type\//) {
                $ref = ModelSEED::Reference->new(ref => $arg);
            } elsif($arg && $arg ne '-') {
                $ref = ModelSEED::Reference->new(ref => "$type/$arg");
            } elsif ($arg && $arg eq '-' && $from_stdin && ! -t STDIN) {
                while (<STDIN>) {
                    my $str = $_;
                    chomp $str;
                    if($str =~ /^$type\//) {
                        $ref = ModelSEED::Reference->new(ref => $str);
                    } else {
                        $ref = ModelSEED::Reference->new(ref => "$type/$str");
                    }
                    push(@$refs, $ref);
                    $ref = undef;
                }
            } else {
                last;
            }
            if(defined($ref)) {
                push(@$refs, $ref);
            }
        }
    }
    if(!defined($ref) && $from_config) {
        my $config = ModelSEED::Configuration->instance;
        $ref = $config->config->{$type};
        $ref = ModelSEED::Reference->new(ref => $ref);
        push(@$refs, $ref);
    }
    return $refs;
}

1;
