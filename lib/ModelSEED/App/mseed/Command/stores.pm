package ModelSEED::App::mseed::Command::stores; 
use ModelSEED::App::stores;
use base 'App::Cmd::Command';
use autouse 'Data::Dumper' => qw(Dumper);
sub abstract { "Alias to mseed-stores command" }
sub execute {
    my ($self, $opt, $args) = @_;
    {
        local @ARGV = @ARGV;
        my $arg0 = shift @ARGV;
        my $app = ModelSEED::App::stores->new;    
        $app->run;
    }
}
1;
