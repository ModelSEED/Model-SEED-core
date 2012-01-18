package ModelSEED::DB::ModelParent::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::ModelParent;

sub object_class { 'ModelSEED::DB::ModelParent' }

__PACKAGE__->make_manager_methods('model_parents');

1;

