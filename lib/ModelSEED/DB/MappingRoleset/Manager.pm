package ModelSEED::DB::MappingRoleset::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::MappingRoleset;

sub object_class { 'ModelSEED::DB::MappingRoleset' }

__PACKAGE__->make_manager_methods('mapping_rolesets');

1;

