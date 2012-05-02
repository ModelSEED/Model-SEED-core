package ModelSEED::App::stores;
use base 'App::Cmd';
sub default_command { 'list' };
sub usage_desc { $_[0]->arg0 . " [command] " }

$ModelSEED::App::stores::typeToClass = {
    file => 'ModelSEED::Database::FileDB',
    mongo => 'ModelSEED::Database::MongoDB',
    rest => 'ModelSEED::Database::Rest',
};

$ModelSEED::App::stores::typeToArgs = {
    file => { directory => [ 'directory:s' => 'Directory to store the database in' ] },
};

1; 
