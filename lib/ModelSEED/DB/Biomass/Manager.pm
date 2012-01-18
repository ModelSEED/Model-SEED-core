package ModelSEED::DB::Biomass::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::Biomass;

sub object_class { 'ModelSEED::DB::Biomass' }

__PACKAGE__->make_manager_methods('biomasses');

1;

