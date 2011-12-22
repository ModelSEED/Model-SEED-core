package ModelSEED::DB::MappingAlias::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::MappingAlias;

sub object_class { 'ModelSEED::DB::MappingAlias' }

__PACKAGE__->make_manager_methods('mapping_alias');

1;

