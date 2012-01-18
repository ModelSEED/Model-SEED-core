package ModelSEED::DB::Reagent::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::Reagent;

sub object_class { 'ModelSEED::DB::Reagent' }

__PACKAGE__->make_manager_methods('reagents');

1;

