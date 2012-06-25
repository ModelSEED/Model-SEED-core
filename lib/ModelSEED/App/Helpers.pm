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

=head3 handle_ref_lookup
This function encapsulates logic for taking a JSON C<data> object
and looking up a uuid C<attribute_name> in that object. C<type> is
the type of object, e.g. 'biochemistry', 'model', etc.  C<opts> is
a hashref containing the following fields:

    $opts = {
        raw  => boolean
        full => boolean
    }

One of these or neither may be true. Raw means raw JSON output;
full means readable format. No options means just print the ref.
=cut
sub handle_ref_lookup {
    my ($self, $store, $data, $attribute_name, $type, $opts) = @_;
    if ($opts->{raw} || $opts->{full}) {
        $ref = ModelSEED::Reference->new(
            type => $type,
            uuid => $data->{$attribute_name}
        );
    }
    if ($opts->{raw}) {
        my $d = $store->get_data($ref);
        return JSON->new->utf8(1)->encode($d);
    } elsif($opts->{full}) {
        my $object = $store->get_object($ref);
        return join("\n", @{$object->createReadableStringArray}) . "\n";
    } else {
        return "$type/". $data->{$attribute_name} . "\n";
    }
}

sub process_ref_string {
    my ($self, $refString, $type, $username) = @_;
    my $count = split(/\//, $refString);
    if($refString eq '' || !defined($refString)) {
        return undef;        
    } elsif ($refString =~ /^$type\//) {
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
    my ($self, $type, $username, $args, $options) = @_;
    my $ref;
    my $from_stdin  = $options->{stdin} // 1;
    my $from_config = $options->{config} // 1;
    my $from_argv   = $options->{argv} // 1;
    my $arg = $args->[0];
    if($from_argv && $arg =~ /^$type\//) {
        $ref = ModelSEED::Reference->new(ref => $arg);
    } elsif($from_argv && $arg && $arg ne '-') {
        $ref = $self->process_ref_string($arg, $type, $username);
        $ref = ModelSEED::Reference->new(ref => $ref);
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
        return undef unless(defined($ref));
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

sub get_object {
    my ($self, $type, $args, $store) = @_;
    $ref = $self->get_base_ref($type, $store->auth->username, $args);
    if(defined($ref)) {
        return ($store->get_object($ref), $ref);
    } else {
        return (undef, $ref);
    }
}

sub get_data {
    my ($self, $type, $args, $store) = @_;
    $ref = $self->get_base_ref($type, $store->auth->username, $args);
    if(defined($ref)) {
        return $store->get_data($ref);
    } else {
        return undef;
    }
}

1;
