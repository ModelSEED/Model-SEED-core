package ModelSEED::App::mseed::Command::bio; 
use ModelSEED::App::bio;
use base 'App::Cmd::Command';
sub abstract { "Alias to ms-bio command" }
sub execute {
    my ($self, $opt, $args) = @_;
    {
        local @ARGV = @ARGV;
        my $arg0 = shift @ARGV;
        my $app = ModelSEED::App::bio->new;    
        $app->run;
    }
}
1;
