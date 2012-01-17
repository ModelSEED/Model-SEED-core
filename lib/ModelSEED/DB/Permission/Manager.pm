package ModelSEED::DB::Permission::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::Permission;

sub object_class { 'ModelSEED::DB::Permission' }

__PACKAGE__->make_manager_methods('permissions');

1;

