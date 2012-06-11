package ModelSEED::App::mseed::Command::model; 
use ModelSEED::App::model;
use base 'App::Cmd::Command';
sub abstract { "Alias to ms-model command" }
sub execute {
    my ($self, $opt, $args) = @_;
    {
        local @ARGV = @ARGV;
        my $arg0 = shift @ARGV;
        my $app = ModelSEED::App::model->new;    
        $app->run;
    }
}
1;
