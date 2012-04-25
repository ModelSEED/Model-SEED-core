package ModelSEED::App::mseed::Command::get;
use base 'App::Cmd::Command';
sub execute {
    my ($self, $opts, $args) = @_;
    return;
}

sub abstract {
    return "List and retrive objects from workspace or datastore.";
}

1;
