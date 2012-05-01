package ModelSEED::App::mseed::Command::login;
use IO::Prompt;
use Try::Tiny;
use Class::Autouse qw(ModelSEED::FIGMODEL ModelSEED::Configuration);
use base 'App::Cmd::Command';

sub abstract { "Login as a user" }
sub usage { "%c COMMAND [username]" }
sub validate_args {
    my ($self, $opt, $args) = @_;
    $self->usage_error("Need to supply a username") unless @$args;
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $username = $args->[0];
    # Prompt for password
    prompt("Password: ", -e => '*');
    my $password = $_;
    my $fm = ModelSEED::FIGMODEL->new();
    my $usrObj = $fm->database->get_object("user", {login => $username});
    unless(defined($usrObj)) {
        try {
            $usrObj = $fm->import_seed_account({
                username => $username,
                password => $password
            });
        } catch {
            die "Error in communicating with SEED authorization service.\n";
        };
    }
    unless(defined($usrObj)) {
        die "Could not find specified user account.\n";
    }
    $fm->authenticate({username => $username, password => $password});
    if (!defined($fm->userObj()) || $fm->userObj()->login() ne $username) {
        die "Invalid password\n"; 
    } else {
        my $conf = ModelSEED::Configuration->new();
        $conf->config->{login} = {
            username => $username,
            password => $fm->userObj->password,
        };
        $conf->save();
    }
}

1;
