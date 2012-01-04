package ModelSEED::DB::ModelCompartment::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::ModelCompartment;

sub object_class { 'ModelSEED::DB::ModelCompartment' }

__PACKAGE__->make_manager_methods('model_compartments');

1;

