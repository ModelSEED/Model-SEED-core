package ModelSEED::DB::MappingCompartment::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::MappingCompartment;

sub object_class { 'ModelSEED::DB::MappingCompartment' }

__PACKAGE__->make_manager_methods('mapping_compartment');

1;

