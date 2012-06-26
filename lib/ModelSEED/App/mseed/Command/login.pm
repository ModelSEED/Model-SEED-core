package ModelSEED::App::mseed::Command::login;
use IO::Prompt::Tiny;
use Module::Load;
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
    # Prompt for password - try to use IO::Prompt if it is installed
    # Otherwise use IO::Prompt::Tiny, which may work on Windows
    my $loaded = 1;
    try {
        load 'IO::Prompt';
    } catch {
        $loaded = 0;
    };
    my $password;
    if($loaded) {
        IO::Prompt::prompt("Password: ", -e => "*");
        $password = $_;
    } else {
        #$password = IO::Prompt::Tiny::prompt("Password: ");
        print "Enter password:";
        $password = <STDIN>;
    }
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
    try {
        $fm->authenticate({username => $username, password => $password});
    } catch {
        die "Invalid password\n";
    };
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
