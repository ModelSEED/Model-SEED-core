package ModelSEED::App::stores::Command::add;
use ModelSEED::Configuration;
use base 'App::Cmd::Command';

$typeToClass = $ModelSEED::App::stores::typeToClass;
$typeToArgs = $ModelSEED::App::stores::typeToArgs;

sub abstract { "Add another store interface" }
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
    foreach my $arg (keys %$requiredArgs) {
        return "--$arg required for $type" unless(defined($opt->{$arg}));
        $config->{$arg} = $opt->{$arg};
    }
    return $config;    
}

1;
