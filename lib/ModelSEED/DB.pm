package ModelSEED::DB;
use Rose::DB;
use Moose;
extends 'Rose::DB';

ModelSEED::DB->register_db(
    domain => 'production',
    type   => 'main',
    driver => 'MySQL',
    database => 'ModelDB',
    host => 'localhost',
    username => 'root',
    server_time_zone => 'UTC',
);

ModelSEED::DB->default_domain('production');
ModelSEED::DB->default_type('main');
