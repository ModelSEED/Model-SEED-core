package ModelSEED::DB::Complex::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::Complex;

sub object_class { 'ModelSEED::DB::Complex' }

__PACKAGE__->make_manager_methods('complex');

1;

