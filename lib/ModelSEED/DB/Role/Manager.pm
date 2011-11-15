package ModelSEED::DB::Role::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::Role;

sub object_class { 'ModelSEED::DB::Role' }

__PACKAGE__->make_manager_methods('role');

1;

