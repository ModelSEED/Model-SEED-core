package ModelSEED::DB::Mapping::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::Mapping;

sub object_class { 'ModelSEED::DB::Mapping' }

__PACKAGE__->make_manager_methods('mapping');

1;

