package ModelSEED::App::stores;
use base 'App::Cmd';
sub default_command { 'list' };
sub usage_desc { $_[0]->arg0 . " [command] " }

$ModelSEED::App::stores::typeToClass = {
    file => 'ModelSEED::FileDB',
    mongo => 'ModelSEED::MongoDB',
    rest => 'ModelSEED::Rest',
};

$ModelSEED::App::stores::typeToArgs = {
    file => { directory => [ 'directory:s' => 'Directory to store the database in' ] },
};

1; 
