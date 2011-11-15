package ModelSEED::DB::MappingComplex::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::MappingComplex;

sub object_class { 'ModelSEED::DB::MappingComplex' }

__PACKAGE__->make_manager_methods('mapping_complex');

1;

