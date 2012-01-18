package ModelSEED::DB::MappingRole::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::MappingRole;

sub object_class { 'ModelSEED::DB::MappingRole' }

__PACKAGE__->make_manager_methods('mapping_roles');

1;

