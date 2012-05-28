package ModelSEED::App::stores::Command::add;
use Class::Autouse qw(ModelSEED::Configuration);
use Data::Dumper;
use base 'App::Cmd::Command';

$typeToClass = $ModelSEED::App::stores::typeToClass;
$typeToArgs = $ModelSEED::App::stores::typeToArgs;
$defaultArgValues = $ModelSEED::App::stores::defaultArgValues;

sub abstract { "Add another store interface" }
sub usage_desc { "stores add name --type type ..." }

sub opt_spec {
    my $spec = [
        [ 'type=s', "Type of interface [".join('|', keys %$typeToClass) ."]" ],
    ];
    foreach my $type (values %$typeToArgs) {
        push(@$spec, values %{$type});
    }
    return @$spec;
}
sub validate_args {
    my ($self, $opt, $args) = @_;
    my $name = $args->[0];
    my $val = $self->_buildConfig($opt, $name);
    unless(ref($val)) {
        $self->usage_error($val);
    }
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $name = shift @$args;
    my $config = $self->_buildConfig($opt, $name);
    my $ms = ModelSEED::Configuration->new();    
    my $stores = $ms->config->{stores};
    my %map = map { $_->{name} => $_ } @$stores; 
    if (defined($map{$name})) {
        $self->usage_error("Store with $name already exists! "
                . "Use the 'update' command to update.");
    }
    push(@{$ms->config->{stores}}, $config);
    $ms->save();
}

sub _buildConfig {
    my ($self, $opt, $name) = @_;
    my $config = {name => $name};
    my $argMap = {
        file => { filename => 1 },
    };
    my $type = $opt->{type};
    # Set the type
    return "--type required" unless(defined($type));
    $config->{type} = $type;

    # Set the class
    return "unknown type $type" unless(defined($typeToClass->{$type}));
    $config->{class} = $typeToClass->{$type};

    # Check the args
    return "unknown type $type" unless(defined($typeToArgs->{$type}));
    my $requiredArgs = $typeToArgs->{$type};
    my $defaults = $defaultArgValues->{$type};

    foreach my $arg (keys %$requiredArgs) {
        my $spec = $requiredArgs->{$arg};
        if (defined($opt->{$arg})) {
            $config->{$arg} = $opt->{$arg};
        } elsif (defined($defaults->{$arg})) {
            $config->{$arg} = $defaults->{$arg};
        } elsif ($spec->[0] =~ /=/) {
            return "--$arg required for $type" unless (defined($opt->{$arg}));
        }
    }
    return $config;    
}

1;
