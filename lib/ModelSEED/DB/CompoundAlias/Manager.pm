package ModelSEED::DB::CompoundAlias::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::CompoundAlias;

sub object_class { 'ModelSEED::DB::CompoundAlias' }

__PACKAGE__->make_manager_methods('compound_alias');

1;

