package ModelSEED::App::mseed::Command::mapping; 
use ModelSEED::App::mapping;
use base 'App::Cmd::Command';
sub abstract { "Alias to ms-mapping command" }
sub execute {
    my ($self, $opt, $args) = @_;
    {
        local @ARGV = @ARGV;
        my $arg0 = shift @ARGV;
        my $app = ModelSEED::App::mapping->new;    
        $app->run;
    }
}
1;
