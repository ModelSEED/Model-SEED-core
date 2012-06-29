package ModelSEED::App::mseed::Command::pp;
use base 'App::Cmd::Command';
use JSON;
sub abstract { return "Pretty print JSON object" }
sub usage_desc { return "ms pp < object.json" }
sub execute {
    my ($self, $opts, $args) = @_;
    my $str;
    {
        local $\;
        $str = <STDIN>;
    }
    print to_json(from_json($str, {allow_nonref=>1}), {pretty=>1}) . "\n";
}

1;
