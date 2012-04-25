package ModelSEED::App::mseed::Command::login;
use ModelSEED::FIGMODEL;
use IO::Prompt;
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
    my $password = prompt("Password: ", -e => '*');
    my $fm = ModelSEED::FIGMODEL->new;
    my $usrObj = $fm->database->get_object("user", {login => $username});
    unless(defined($usrObj)) {
        $usrObj = $fm->import_seed_account({
            username => $username,
            password => $password
        });
    }
    unless(defined($usrObj)) {
        die "Could not find specified user account.\n";
    }
    $fm->authenticate({username => $username,password => $password});
    if (!defined($fm->userObj()) || $fm->userObj()->login() ne $username) {
        die "Invalid password\n"; 
    }
}

1;
