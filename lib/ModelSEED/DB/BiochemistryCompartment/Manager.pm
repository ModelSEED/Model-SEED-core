package ModelSEED::DB::BiochemistryCompartment::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::BiochemistryCompartment;

sub object_class { 'ModelSEED::DB::BiochemistryCompartment' }

__PACKAGE__->make_manager_methods('biochemistry_compartments');

1;

