package ModelSEED::App::stores;
use base 'App::Cmd';
sub default_command { 'list' };
sub usage_desc { $_[0]->arg0 . " [command] " }

$ModelSEED::App::stores::typeToClass = {
    file => 'ModelSEED::Database::FileDB',
    mongo => 'ModelSEED::Database::MongoDBSimple',
    rest => 'ModelSEED::Database::Rest',
};

$ModelSEED::App::stores::typeToArgs = {
    file => { directory => [ 'directory=s' => 'Directory to store the database in' ] },
    mongo => { host => [ 'host=s' => 'Hostname of machine running mongod' ],
               db_name => [ 'db_name:s' => 'Database name to use for storage' ],,
               username => [ 'username:s' => 'Username to login' ],
               password => [ 'password:s' => 'Password to login' ],
    },
};

$ModelSEED::App::stores::defaultArgValues = {
    file => {},
    mongo => {
        db_name => 'ModelSeed'
    },
    rest => {},
};

1; 
