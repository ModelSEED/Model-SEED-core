package ModelSEED::DB::Compartment::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::Compartment;

sub object_class { 'ModelSEED::DB::Compartment' }

__PACKAGE__->make_manager_methods('compartment');

1;

