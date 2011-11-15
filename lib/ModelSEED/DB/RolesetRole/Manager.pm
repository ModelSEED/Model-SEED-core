package ModelSEED::DB::RolesetRole::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::RolesetRole;

sub object_class { 'ModelSEED::DB::RolesetRole' }

__PACKAGE__->make_manager_methods('roleset_role');

1;

