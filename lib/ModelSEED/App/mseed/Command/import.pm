package ModelSEED::App::mseed::Command::import; 
use ModelSEED::App::stores;
use base 'App::Cmd::Command';
use Class::Autouse qw(
    ModelSEED::App::import
);
sub abstract { "Import genomes, models, etc. from external sources" }
sub execute {
    my ($self, $opt, $args) = @_;
    {
        local @ARGV = @ARGV;
        my $arg0 = shift @ARGV;
        my $app = ModelSEED::App::import->new;    
        $app->run;
    }
}
1;
