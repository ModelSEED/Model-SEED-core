package ModelSEED::DB::DB::AutoBase1;

use strict;

use base 'Rose::DB';

__PACKAGE__->use_private_registry;

__PACKAGE__->register_db
(
  driver => 'sqlite',
  dsn    => 'dbi:SQLite:dbname=/home/devoid/test.db;',
);

1;
