package ModelSEED::DB::ModelAlias::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::ModelAlias;

sub object_class { 'ModelSEED::DB::ModelAlias' }

__PACKAGE__->make_manager_methods('model_aliases');

1;

