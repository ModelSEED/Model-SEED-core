package ModelSEED::DB::RolesetParent::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::RolesetParent;

sub object_class { 'ModelSEED::DB::RolesetParent' }

__PACKAGE__->make_manager_methods('roleset_parents');

1;

