package ModelSEED::DB::Model::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::Model;

sub object_class { 'ModelSEED::DB::Model' }

__PACKAGE__->make_manager_methods('models');

1;

