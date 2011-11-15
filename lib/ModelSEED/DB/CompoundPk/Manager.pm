package ModelSEED::DB::CompoundPk::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::CompoundPk;

sub object_class { 'ModelSEED::DB::CompoundPk' }

__PACKAGE__->make_manager_methods('compound_pk');

1;

