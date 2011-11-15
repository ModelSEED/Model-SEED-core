package ModelSEED::DB::Compound::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::Compound;

sub object_class { 'ModelSEED::DB::Compound' }

__PACKAGE__->make_manager_methods('compound');

1;

