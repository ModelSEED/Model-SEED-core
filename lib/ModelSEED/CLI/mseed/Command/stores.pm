package ModelSEED::CLI::mseed::Command::stores; 
use ModelSEED::CLI::stores;
use base 'App::Cmd::Command';
use autouse 'Data::Dumper' => qw(Dumper);
sub abstract { "Alias to mseed-stores command" }
sub execute {
    my ($self, $opt, $args) = @_;
    {
        local @ARGV = @ARGV;
        my $arg0 = shift @ARGV;
        my $app = ModelSEED::CLI::stores->new;    
        $app->run;
    }
}
1;
