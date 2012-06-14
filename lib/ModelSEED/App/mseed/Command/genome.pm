package ModelSEED::App::mseed::Command::genome; 
use ModelSEED::App::genome;
use base 'App::Cmd::Command';
sub abstract { "Alias to ms-genome command" }
sub execute {
    my ($self, $opt, $args) = @_;
    {
        local @ARGV = @ARGV;
        my $arg0 = shift @ARGV;
        my $app = ModelSEED::App::genome->new;    
        $app->run;
    }
}
1;
