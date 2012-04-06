package ModelSEED::CLI::stores;
use base 'App::Cmd';
sub default_command { 'list' };

$typeToClass = {
    file => 'ModelSEED::FileDB',
    mongo => 'ModelSEED::MongoDB',
    rest => 'ModelSEED::Rest',
};

$typeToArgs = {
    file => { directory => [ 'directory:s' => 'Directory to store the database in' ] },
};

1; 
