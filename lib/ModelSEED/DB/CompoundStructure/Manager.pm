package ModelSEED::DB::CompoundStructure::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::CompoundStructure;

sub object_class { 'ModelSEED::DB::CompoundStructure' }

__PACKAGE__->make_manager_methods('compound_structure');

1;

