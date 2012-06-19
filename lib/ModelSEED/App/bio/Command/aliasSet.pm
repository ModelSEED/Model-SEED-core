package ModelSEED::App::bio::Command::aliasSet;
use base 'App::Cmd::Command';
use Try::Tiny;
use Class::Autouse qw(
    ModelSEED::Store
    ModelSEED::Auth::Factory
    ModelSEED::Reference
    ModelSEED::Configuration
    ModelSEED::MS::Biochemistry
);

sub abstract { return "Functions on alias sets"; }

sub usage_desc { return <<END;
bio aliasSet [ options ]

END
}

sub opt_spec {
    return (
        ["validate", "Run validation logic on alias set"],
        ["list", "List available alias sets"],
        ["store|s:s", "Identify which store to save the annotation to"],
        ["verbose|v", "Print detailed output of import status"],
        ["dry|d", "Perform a dry run; that is, do everything but saving"],
        ["mapping|m:s", "Select the preferred mapping object to use when importing the annotation"],
    );
}

sub execute {
    my ($self, $opts, $args) = @_;
    my $biochem = $self->_getBiochemistry($args);
    if ($opts->{validate}) {
        $self->_validate($biochem, $args, $opts); 
    } elsif($opts->{list}) {
        $self->_list($biochem, $args, $opts);
    }

}

sub _validate {
    my ($self, $bio, $aliasSets, $opts) = @_;
    $bio = ModelSEED::MS::Biochemistry->new($bio);
    if(!defined($aliasSets)) {
        $aliasSets = [ map { $_->type } @{$bio->compoundAliasSets} ];
        push(@$aliasSets, [ map { $_->type } @{$bio->reactionAliasSets} ]);
    }
    my $aliasSetMap = { map { $_ => 1 } @$aliasSets };
    foreach my $set (@{$bio->reactionAliasSets}) {
        if(defined($aliasSetMap->{$set->type})) {
            my $errors = $set->validate();
            if(@$errors) {
                print "Errors in ".$set->type."\n";
                print join("\n", $errors);
            }
        }
    }
    foreach my $set (@{$bio->compoundAliasSets}) {
        if(defined($aliasSetMap->{$set->type})) {
            my $errors = $set->validate();
            if(@$errors) {
                print "Errors in ".$set->type."\n";
                print join("\n", $errors);
            }
        }
    }
}

sub _list {
    my ($self, $bio, $aliasSets, $opts) = @_;
    my $set = {};
    map { $set->{$_->{type}} = 1 } @{$bio->{compoundAliasSets}};
    map { $set->{$_->{type}} = 1 } @{$bio->{reactionAliasSets}};
    print join("\n", sort keys %$set);
}

sub _getBiochemistry {
    my ($self, $args) = @_;
    my $arg = shift @$args; 
    my ($ref, $bio);
    if($arg =~ /biochemistry/) {
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
         $ref = $config->config->{biochemistry};
     }
     my $auth  = ModelSEED::Auth::Factory->new->from_config;
     my $store = ModelSEED::Store->new(auth => $auth);
     if(defined($ref)) {
         $bio = $store->get_data($ref);
     }
     return $bio;
}

1;
