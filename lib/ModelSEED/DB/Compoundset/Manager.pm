package ModelSEED::DB::Compoundset::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::Compoundset;

sub object_class { 'ModelSEED::DB::Compoundset' }

__PACKAGE__->make_manager_methods('compoundset');

1;

