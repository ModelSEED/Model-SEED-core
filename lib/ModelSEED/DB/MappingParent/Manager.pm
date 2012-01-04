package ModelSEED::DB::MappingParent::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::MappingParent;

sub object_class { 'ModelSEED::DB::MappingParent' }

__PACKAGE__->make_manager_methods('mapping_parents');

1;

