package ModelSEED::DB::CompoundAlia::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::CompoundAlia;

sub object_class { 'ModelSEED::DB::CompoundAlia' }

__PACKAGE__->make_manager_methods('compound_alias');

1;

