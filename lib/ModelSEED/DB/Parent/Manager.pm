package ModelSEED::DB::Parent::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::Parent;

sub object_class { 'ModelSEED::DB::Parent' }

__PACKAGE__->make_manager_methods('parent');

1;

