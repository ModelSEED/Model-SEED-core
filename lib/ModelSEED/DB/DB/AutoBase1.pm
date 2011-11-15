package ModelSEED::DB::DB::AutoBase1;

use strict;

use base 'Rose::DB';

__PACKAGE__->use_private_registry;

__PACKAGE__->register_db
(
  driver   => 'mysql',
  dsn      => 'dbi:mysql:dbname=ModelDB;host=localhost',
  username => 'root',
);

1;
