package ModelSEED::DB::ComplexRole::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::ComplexRole;

sub object_class { 'ModelSEED::DB::ComplexRole' }

__PACKAGE__->make_manager_methods('complex_role');

1;

